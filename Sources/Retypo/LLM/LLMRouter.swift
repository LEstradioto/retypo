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
            .openai: OpenAIResponsesProvider(memory: memory),
            .claudeCode: ClaudeCodeProvider(),
            .codex: CodexProvider()
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
            extraHeaders: ["HTTP-Referer": "https://retypo.local", "X-Title": "Retypo"]
        )
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        guard let client = providers[request.provider] else { throw LLMError.invalidResponse }
        return try await client.complete(request, apiKey: try credentials(for: request.provider))
    }

    func listModels(for provider: ProviderKind) async throws -> [ProviderModel] {
        guard let client = providers[provider] else { throw LLMError.invalidResponse }
        return try await client.listModels(apiKey: try credentials(for: provider))
    }

    /// CLI providers authenticate through the signed-in `claude` / `codex`,
    /// so there is no key to look up or to fail on.
    private func credentials(for provider: ProviderKind) throws -> String {
        guard !provider.usesLocalCLI else { return "" }
        guard let apiKey = APIKeyStore.apiKey(for: provider) else { throw LLMError.missingAPIKey(provider) }
        return apiKey
    }
}
