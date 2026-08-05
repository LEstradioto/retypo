import Foundation

final class OpenAIResponsesProvider: LLMProviderClient {
    private let baseURL = URL(staticString: "https://api.openai.com/v1")
    private let modelProvider: OpenAICompatibleProvider
    private let transport: ProviderTransport

    init(memory: RejectedParameterMemory) {
        transport = ProviderTransport(provider: .openai, memory: memory)
        modelProvider = OpenAICompatibleProvider(
            baseURL: URL(staticString: "https://api.openai.com/v1"),
            transport: transport
        )
    }

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let object = try await transport.send(responsesPost(request, apiKey: apiKey), model: request.model)
        guard let text = extractText(from: object), !text.isEmpty else {
            throw LLMError.emptyCompletion(OpenAIBudget.emptyReason(object))
        }
        return LLMResponse(text: text, usage: parseUsage(object["usage"] as? [String: Any]))
    }

    func listModels(apiKey: String) async throws -> [ProviderModel] {
        try await modelProvider.listModels(apiKey: apiKey)
    }

    private func responsesPost(_ request: LLMRequest, apiKey: String) -> ProviderPost {
        ProviderPost(
            url: baseURL.appendingPathComponent("responses"),
            headers: ["Authorization": "Bearer \(apiKey)"],
            body: responsesBody(request),
            optionalKeys: ["temperature", "top_p", "reasoning"]
        )
    }

    /// Reasoning models reject `temperature` and burn `max_output_tokens` on
    /// hidden reasoning; chat models reject `reasoning`. Send one or the other.
    private func responsesBody(_ request: LLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "instructions": request.system,
            "input": request.user,
            "max_output_tokens": OpenAIBudget.maxOutputTokens(for: request)
        ]
        if ModelParameterSupport.openAIUsesReasoning(request.model) {
            body["reasoning"] = ["effort": OpenAIBudget.reasoningEffort]
        } else {
            body["temperature"] = request.temperature
        }
        return body
    }

    /// Reasoning items sit in `output` next to the message and carry an empty
    /// `content` array, so they contribute nothing here.
    private func extractText(from object: [String: Any]) -> String? {
        if let direct = object["output_text"] as? String, !direct.isEmpty { return direct }
        guard let output = object["output"] as? [[String: Any]] else { return nil }
        let text = output.flatMap { item -> [String] in
            let content = item["content"] as? [[String: Any]] ?? []
            return content.compactMap { $0["text"] as? String }
        }.joined()
        return text.isEmpty ? nil : text
    }

    private func parseUsage(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage else { return .zero }
        let input = usage["input_tokens"] as? Int ?? usage["prompt_tokens"] as? Int ?? 0
        let output = usage["output_tokens"] as? Int ?? usage["completion_tokens"] as? Int ?? 0
        return TokenUsage(inputTokens: input, outputTokens: output)
    }
}
