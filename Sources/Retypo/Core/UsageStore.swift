import Foundation

struct TokenUsage: Codable, Hashable {
    var inputTokens: Int
    var outputTokens: Int
    /// Server-side web searches, billed per search on top of tokens. `nil`
    /// for runs without search and for every entry saved before enhanced modes.
    var webSearches: Int?
    var totalTokens: Int { inputTokens + outputTokens }

    static let zero = TokenUsage(inputTokens: 0, outputTokens: 0)

    /// The usage of a run made of several requests (an enhanced mode's rounds).
    func adding(_ other: TokenUsage) -> TokenUsage {
        let searches = (webSearches ?? 0) + (other.webSearches ?? 0)
        return TokenUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            webSearches: searches > 0 ? searches : nil
        )
    }
}

struct ModelPricing: Codable, Hashable {
    var inputPerMillion: Double
    var outputPerMillion: Double

    static let zero = ModelPricing(inputPerMillion: 0, outputPerMillion: 0)
}

struct CostSnapshot: Codable, Hashable {
    var usage: TokenUsage
    var costUSD: Double?
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var provider: ProviderKind
    var model: String
    var actionID: String
    var actionTitle: String
    /// The system prompt actually sent to the LLM. For static modes this
    /// matches the action's instruction; for Freeform it's whatever the
    /// user typed at run-time. Optional for backward-compat with older
    /// history.json files written before this field existed.
    var instruction: String?
    var input: String
    var output: String
    var diff: String
    var usage: TokenUsage
    var costUSD: Double?
}

enum PricingStore {
    private static let file = PersistedFile<[String: ModelPricing]>(
        url: AppFiles.url("pricing.json"),
        fallback: [:]
    )

    static func load() -> [String: ModelPricing] { file.load() }
    static func save(_ pricing: [String: ModelPricing]) { file.save(pricing) }
    static func key(provider: ProviderKind, model: String) -> String { "\(provider.rawValue)::\(model)" }
}

enum HistoryStore {
    private static let file = PersistedFile<[HistoryEntry]>(
        url: AppFiles.url("history.json"),
        fallback: []
    )

    static func load() -> [HistoryEntry] { file.load() }
    static func save(_ entries: [HistoryEntry], limit: Int = 10) {
        file.save(Array(entries.prefix(max(1, limit))))
    }
}

struct UsageLedgerEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var provider: ProviderKind
    var model: String
    var usage: TokenUsage
    var costUSD: Double?
}

enum UsageLedgerStore {
    private static let file = PersistedFile<[UsageLedgerEntry]>(
        url: AppFiles.url("usage-ledger.json"),
        fallback: []
    )

    static func load() -> [UsageLedgerEntry] { file.load() }
    static func save(_ entries: [UsageLedgerEntry]) {
        file.save(Array(entries.prefix(500)))
    }
}

struct DraftSnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var text: String
}

enum DraftSnapshotStore {
    private static let file = PersistedFile<[DraftSnapshot]>(
        url: AppFiles.url("draft-history.json"),
        fallback: []
    )

    static func load() -> [DraftSnapshot] { file.load() }
    static func save(_ entries: [DraftSnapshot]) {
        file.save(Array(entries.prefix(20)))
    }
}

struct CandidateResult: Identifiable, Hashable {
    var id: UUID = UUID()
    var action: EditAction
    var output: String
    var diff: String
    /// The candidate against the draft it was run on, for its card.
    var changes: TextDiff = .none
    var usage: TokenUsage
    var costUSD: Double?
}

/// Text captured from another app by the global hotkey, waiting for a
/// conscious paste (smart-paste shortcut or header dot). Never written
/// into the editor on its own.
struct StagedImport: Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var source: String
}
