import Foundation

final class AnthropicProvider: LLMProviderClient {
    private let baseURL = URL(staticString: "https://api.anthropic.com/v1")
    private let transport: ProviderTransport
    private let sender: ProviderSending

    /// `sender` replaces the network for tests; the model list always uses
    /// the transport.
    init(memory: RejectedParameterMemory, sender: ProviderSending? = nil) {
        let transport = ProviderTransport(provider: .anthropic, memory: memory)
        self.transport = transport
        self.sender = sender ?? transport
    }

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let object = try await sender.send(messagesPost(request, apiKey: apiKey), model: request.model)
        guard let text = extractText(from: object), !text.isEmpty else {
            throw LLMError.emptyCompletion(AnthropicBudget.emptyReason(object))
        }
        return LLMResponse(text: text, usage: AnthropicWire.usage(in: object))
    }

    /// An enhanced mode's inline documents make the system prompt long and
    /// identical across runs of the mode; caching it makes repeats about
    /// ten times cheaper on input. Short prompts stay uncached: they fall
    /// under the minimum cacheable length anyway.
    static let cachedSystemCharacters = 6_000

    /// `/v1/models` pages at 20 by default, so ask for the full catalogue in
    /// one shot — otherwise the newest models push older ones off the list.
    func listModels(apiKey: String) async throws -> [ProviderModel] {
        var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "1000")]
        guard let url = components?.url else { throw LLMError.invalidURL }
        let object = try await transport.get(url: url, headers: headers(apiKey))
        let items = object["data"] as? [[String: Any]] ?? []
        return items.compactMap(decodeModel)
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private func messagesPost(_ request: LLMRequest, apiKey: String) -> ProviderPost {
        ProviderPost(
            url: baseURL.appendingPathComponent("messages"),
            headers: headers(apiKey),
            body: messagesBody(request),
            optionalKeys: ["temperature", "top_p", "top_k", "thinking", "cache_control"]
        )
    }

    private func messagesBody(_ request: LLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "system": request.system,
            "messages": [["role": "user", "content": request.user]],
            "max_tokens": AnthropicBudget.maxTokens(for: request)
        ]
        if ModelParameterSupport.anthropicAcceptsTemperature(request.model) {
            body["temperature"] = request.temperature
        }
        if request.system.count >= Self.cachedSystemCharacters {
            body["cache_control"] = ["type": "ephemeral"]
        }
        return body
    }

    private func headers(_ apiKey: String) -> [String: String] {
        ["x-api-key": apiKey, "anthropic-version": "2023-06-01"]
    }

    /// Thinking blocks arrive in `content` alongside the answer and carry no
    /// `text` field, so they drop out here rather than polluting the result.
    private func extractText(from object: [String: Any]) -> String? {
        let blocks = object["content"] as? [[String: Any]]
        return blocks?.compactMap { $0["text"] as? String }.joined()
    }

    private func decodeModel(_ item: [String: Any]) -> ProviderModel? {
        guard let id = item["id"] as? String else { return nil }
        let name = item["display_name"] as? String ?? item["name"] as? String ?? id
        return ProviderModel(id: id, name: name)
    }
}
