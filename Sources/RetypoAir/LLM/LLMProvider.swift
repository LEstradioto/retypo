import Foundation

enum ProviderKind: String, CaseIterable, Identifiable, Codable {
    case groq
    case anthropic
    case openai
    case openrouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: "Groq"
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .openrouter: "OpenRouter"
        }
    }

    var apiKeyEnvironmentName: String {
        switch self {
        case .groq: "GROQ_API_KEY"
        case .anthropic: "ANTHROPIC_API_KEY"
        case .openai: "OPENAI_API_KEY"
        case .openrouter: "OPENROUTER_API_KEY"
        }
    }
}

struct ProviderModel: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var description: String?
    var contextLength: Int?
    var pricing: ModelPricing?

    init(id: String, name: String? = nil, description: String? = nil, contextLength: Int? = nil, pricing: ModelPricing? = nil) {
        self.id = id
        self.name = name ?? id
        self.description = description
        self.contextLength = contextLength
        self.pricing = pricing
    }
}

struct LLMRequest {
    var provider: ProviderKind
    var model: String
    var system: String
    var user: String
    var maxTokens: Int = 2_000
    var temperature: Double = 0.0
}

struct LLMResponse {
    var text: String
    var usage: TokenUsage = .zero
}

enum LLMError: LocalizedError {
    case missingAPIKey(ProviderKind)
    case missingModel(ProviderKind)
    case invalidURL
    case badStatus(Int, String)
    case invalidResponse
    case parseFailed(String)
    /// The call succeeded but carried no answer — reasoning/thinking models
    /// can spend the whole token budget before emitting a visible token.
    case emptyCompletion(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): "Missing \(provider.apiKeyEnvironmentName)"
        case .missingModel(let provider): "Select a \(provider.displayName) model first"
        case .invalidURL: "Invalid API URL"
        case .badStatus(let code, let body): "API error \(code): \(ProviderErrorMessage.summary(body))"
        case .invalidResponse: "Invalid API response"
        case .parseFailed(let body): "Could not parse response: \(body.prefix(280))"
        case .emptyCompletion(let reason): "Model returned no text (\(reason))"
        }
    }
}

protocol LLMProviderClient {
    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse
    func listModels(apiKey: String) async throws -> [ProviderModel]
}

enum APIKeyStore {
    static func apiKey(for provider: ProviderKind) -> String? {
        guard let raw = getenv(provider.apiKeyEnvironmentName) else { return nil }
        let value = String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
