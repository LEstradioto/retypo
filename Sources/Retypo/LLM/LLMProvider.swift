import Foundation

enum ProviderKind: String, CaseIterable, Identifiable, Codable {
    case groq
    case anthropic
    case openai
    case openrouter
    /// Runs through the signed-in `claude` CLI — billed to the Claude
    /// subscription, not to an API key.
    case claudeCode
    /// Runs through the signed-in `codex` CLI — billed to the ChatGPT plan.
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: "Groq"
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .openrouter: "OpenRouter"
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }

    /// `nil` for providers that authenticate through a signed-in local CLI.
    var apiKeyEnvironmentName: String? {
        switch self {
        case .groq: "GROQ_API_KEY"
        case .anthropic: "ANTHROPIC_API_KEY"
        case .openai: "OPENAI_API_KEY"
        case .openrouter: "OPENROUTER_API_KEY"
        case .claudeCode, .codex: nil
        }
    }

    var usesLocalCLI: Bool { apiKeyEnvironmentName == nil }
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
    /// Set only for an enhanced run on Claude Code or Codex: what the CLI's
    /// own read, search and web tools may use. `nil` keeps them all off.
    var research: CLIResearchAccess?
}

/// What an enhanced run opens up on a CLI provider. Claude Code and Codex
/// bring their own read, search and web tools; Retypo only allows them.
struct CLIResearchAccess: Equatable {
    /// Attached folders, granted with `--add-dir`.
    var folders: [String]
    /// The folder the CLI starts in, holding copies of the attached single
    /// files (see `CLIResearchWorkspace`). nil: a fresh empty folder.
    var workspace: URL?
    var webSearch: Bool

    var readsFiles: Bool { !folders.isEmpty || workspace != nil }

    init(folders: [String], workspace: URL? = nil, webSearch: Bool) {
        self.folders = folders
        self.workspace = workspace
        self.webSearch = webSearch
    }
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
    /// A local CLI provider could not be launched — usually not installed,
    /// or installed somewhere a GUI app's minimal PATH cannot see.
    case cliNotFound(String)
    /// The CLI ran but reported a failure.
    case cliFailed(String, String)
    /// The call succeeded but carried no answer — reasoning/thinking models
    /// can spend the whole token budget before emitting a visible token.
    case emptyCompletion(String)
    /// An enhanced mode used every research round without answering.
    case researchUnfinished(Int)
    /// The enhanced mode needs something this provider does not offer.
    case enhancedUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): "Missing \(provider.apiKeyEnvironmentName ?? provider.displayName) credentials"
        case .missingModel(let provider): "Select a \(provider.displayName) model first"
        case .invalidURL: "Invalid API URL"
        case .badStatus(let code, let body): "API error \(code): \(ProviderErrorMessage.summary(body))"
        case .invalidResponse: "Invalid API response"
        case .parseFailed(let body): "Could not parse response: \(body.prefix(280))"
        case .emptyCompletion(let reason): "Model returned no text (\(reason))"
        case .cliNotFound(let tool): "`\(tool)` not installed — install the CLI and sign in, then Refresh"
        case .cliFailed(let tool, let message): "\(tool): \(message)"
        case .researchUnfinished(let rounds): "Still researching after \(rounds) rounds. Make the instruction more specific or attach fewer files"
        case .enhancedUnavailable(let reason): reason
        }
    }
}

protocol LLMProviderClient {
    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse
    func listModels(apiKey: String) async throws -> [ProviderModel]
}

enum APIKeyStore {
    static func apiKey(for provider: ProviderKind) -> String? {
        guard let name = provider.apiKeyEnvironmentName, let raw = getenv(name) else { return nil }
        let value = String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
