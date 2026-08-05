import Foundation

final class LLMRouter {
    private let providers: [ProviderKind: LLMProviderClient]

    init() {
        // One memory shared by every provider: a parameter a model rejects is
        // learned once and skipped for the rest of the session.
        let memory = RejectedParameterMemory()
        providers = [
            .groq: Self.groq(memory),
            .openrouter: Self.openRouter(memory),
            .anthropic: AnthropicProvider(memory: memory),
            .openai: OpenAIResponsesProvider(memory: memory)
        ]
    }

    private static func groq(_ memory: RejectedParameterMemory) -> LLMProviderClient {
        OpenAICompatibleProvider(
            baseURL: URL(staticString: "https://api.groq.com/openai/v1"),
            transport: ProviderTransport(provider: .groq, memory: memory)
        )
    }

    private static func openRouter(_ memory: RejectedParameterMemory) -> LLMProviderClient {
        OpenAICompatibleProvider(
            baseURL: URL(staticString: "https://openrouter.ai/api/v1"),
            transport: ProviderTransport(provider: .openrouter, memory: memory),
            extraHeaders: ["HTTP-Referer": "https://retypo-air.local", "X-Title": "Retypo Air"]
        )
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        guard let apiKey = APIKeyStore.apiKey(for: request.provider) else { throw LLMError.missingAPIKey(request.provider) }
        guard let client = providers[request.provider] else { throw LLMError.invalidResponse }
        return try await client.complete(request, apiKey: apiKey)
    }

    func listModels(for provider: ProviderKind) async throws -> [ProviderModel] {
        guard let apiKey = APIKeyStore.apiKey(for: provider) else { throw LLMError.missingAPIKey(provider) }
        guard let client = providers[provider] else { throw LLMError.invalidResponse }
        return try await client.listModels(apiKey: apiKey)
    }
}
