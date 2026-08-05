import Foundation

final class OpenAICompatibleProvider: LLMProviderClient {
    private let baseURL: URL
    private let extraHeaders: [String: String]
    private let transport: ProviderTransport

    init(baseURL: URL, transport: ProviderTransport, extraHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.transport = transport
        self.extraHeaders = extraHeaders
    }

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let object = try await transport.send(chatPost(request, apiKey: apiKey), model: request.model)
        guard let text = extractText(from: object) else {
            throw LLMError.emptyCompletion(finishReason(object))
        }
        return LLMResponse(text: text, usage: parseUsage(object["usage"] as? [String: Any]))
    }

    func listModels(apiKey: String) async throws -> [ProviderModel] {
        let object = try await transport.get(url: baseURL.appendingPathComponent("models"), headers: headers(apiKey))
        let items = object["data"] as? [[String: Any]] ?? []
        return items.compactMap(decodeModel)
            .filter { ModelCatalogFilter.isTextModel($0.id) }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private func chatPost(_ request: LLMRequest, apiKey: String) -> ProviderPost {
        let body: [String: Any] = [
            "model": request.model,
            "messages": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.user]
            ],
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]
        return ProviderPost(
            url: baseURL.appendingPathComponent("chat/completions"),
            headers: headers(apiKey),
            body: body,
            optionalKeys: ["temperature", "top_p"]
        )
    }

    private func headers(_ apiKey: String) -> [String: String] {
        extraHeaders.merging(["Authorization": "Bearer \(apiKey)"]) { _, new in new }
    }

    private func extractText(from object: [String: Any]) -> String? {
        let choices = object["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String
    }

    private func finishReason(_ object: [String: Any]) -> String {
        let choices = object["choices"] as? [[String: Any]]
        guard let reason = choices?.first?["finish_reason"] as? String else { return "no content returned" }
        return reason == "length" ? "hit the token limit before answering" : "finish reason: \(reason)"
    }

    private func decodeModel(_ item: [String: Any]) -> ProviderModel? {
        guard let id = item["id"] as? String else { return nil }
        let name = item["name"] as? String ?? id
        let description = item["description"] as? String
        let context = item["context_length"] as? Int ?? item["contextLength"] as? Int
        let pricing = parseModelPricing(item["pricing"] as? [String: Any])
        return ProviderModel(id: id, name: name, description: description, contextLength: context, pricing: pricing)
    }

    private func parseModelPricing(_ pricing: [String: Any]?) -> ModelPricing? {
        guard let pricing else { return nil }
        func doubleValue(_ key: String) -> Double? {
            if let value = pricing[key] as? Double { return value }
            if let value = pricing[key] as? Int { return Double(value) }
            if let value = pricing[key] as? String { return Double(value) }
            return nil
        }
        guard let prompt = doubleValue("prompt") ?? doubleValue("input"),
              let completion = doubleValue("completion") ?? doubleValue("output") else { return nil }
        // OpenRouter exposes prices per token; Retypo stores USD per 1M tokens.
        return ModelPricing(inputPerMillion: prompt * 1_000_000, outputPerMillion: completion * 1_000_000)
    }

    private func parseUsage(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage else { return .zero }
        let input = usage["prompt_tokens"] as? Int ?? usage["input_tokens"] as? Int ?? 0
        let output = usage["completion_tokens"] as? Int ?? usage["output_tokens"] as? Int ?? 0
        return TokenUsage(inputTokens: input, outputTokens: output)
    }
}
