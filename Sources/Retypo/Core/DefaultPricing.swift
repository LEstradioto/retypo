import Foundation

enum DefaultPricing {
    static let exact: [String: ModelPricing] = [
        // OpenAI text models, USD per 1M tokens (platform pricing, standard tier)
        "openai::gpt-5.5": .init(inputPerMillion: 5.00, outputPerMillion: 30.00),
        "openai::gpt-5.4": .init(inputPerMillion: 2.50, outputPerMillion: 15.00),
        "openai::gpt-5.4-mini": .init(inputPerMillion: 0.75, outputPerMillion: 4.50),
        "openai::gpt-5.2": .init(inputPerMillion: 1.75, outputPerMillion: 14.00),
        "openai::gpt-5.2-chat-latest": .init(inputPerMillion: 1.75, outputPerMillion: 14.00),
        "openai::gpt-5.2-codex": .init(inputPerMillion: 1.75, outputPerMillion: 14.00),
        "openai::gpt-5.1": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5.1-chat-latest": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5.1-codex": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5.1-codex-max": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5-chat-latest": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5-codex": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5-mini": .init(inputPerMillion: 0.25, outputPerMillion: 2.00),
        "openai::gpt-5-nano": .init(inputPerMillion: 0.05, outputPerMillion: 0.40),
        "openai::gpt-5.2-pro": .init(inputPerMillion: 21.00, outputPerMillion: 168.00),
        "openai::gpt-5-pro": .init(inputPerMillion: 15.00, outputPerMillion: 120.00),
        "openai::gpt-4.1": .init(inputPerMillion: 2.00, outputPerMillion: 8.00),
        "openai::gpt-4.1-mini": .init(inputPerMillion: 0.40, outputPerMillion: 1.60),
        "openai::gpt-4.1-nano": .init(inputPerMillion: 0.10, outputPerMillion: 0.40),
        "openai::gpt-4o": .init(inputPerMillion: 2.50, outputPerMillion: 10.00),
        "openai::gpt-4o-2024-05-13": .init(inputPerMillion: 5.00, outputPerMillion: 15.00),
        "openai::gpt-4o-mini": .init(inputPerMillion: 0.15, outputPerMillion: 0.60),

        // Anthropic Claude models, USD per 1M tokens (base input/output)
        "anthropic::claude-opus-4-7": .init(inputPerMillion: 5.00, outputPerMillion: 25.00),
        "anthropic::claude-opus-4-6": .init(inputPerMillion: 5.00, outputPerMillion: 25.00),
        "anthropic::claude-opus-4-5": .init(inputPerMillion: 5.00, outputPerMillion: 25.00),
        "anthropic::claude-opus-4-5-20251101": .init(inputPerMillion: 5.00, outputPerMillion: 25.00),
        "anthropic::claude-opus-4-1": .init(inputPerMillion: 15.00, outputPerMillion: 75.00),
        "anthropic::claude-opus-4": .init(inputPerMillion: 15.00, outputPerMillion: 75.00),
        "anthropic::claude-sonnet-4-6": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-sonnet-4-5": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-sonnet-4-5-20250929": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-sonnet-4": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-3-7-sonnet": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-3-5-sonnet": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-haiku-4-5-20251001": .init(inputPerMillion: 1.00, outputPerMillion: 5.00),
        "anthropic::claude-haiku-4-5": .init(inputPerMillion: 1.00, outputPerMillion: 5.00),
        "anthropic::claude-3-5-haiku-latest": .init(inputPerMillion: 0.80, outputPerMillion: 4.00),
        "anthropic::claude-3-5-haiku-20241022": .init(inputPerMillion: 0.80, outputPerMillion: 4.00),
        "anthropic::claude-3-5-haiku": .init(inputPerMillion: 0.80, outputPerMillion: 4.00),
        "anthropic::claude-3-haiku": .init(inputPerMillion: 0.25, outputPerMillion: 1.25),
        "anthropic::claude-3-opus": .init(inputPerMillion: 15.00, outputPerMillion: 75.00),

        // Groq public pricing table, USD per 1M tokens
        "groq::openai/gpt-oss-20b": .init(inputPerMillion: 0.075, outputPerMillion: 0.30),
        "groq::openai/gpt-oss-120b": .init(inputPerMillion: 0.15, outputPerMillion: 0.60),
        "groq::gpt-oss-20b": .init(inputPerMillion: 0.075, outputPerMillion: 0.30),
        "groq::gpt-oss-120b": .init(inputPerMillion: 0.15, outputPerMillion: 0.60)
    ]

    /// Pattern table per provider. Order matters: more specific prefixes first
    /// so the first substring match wins.
    private static let patterns: [ProviderKind: [(String, ModelPricing)]] = [
        .anthropic: [
            ("opus-4-7", .init(inputPerMillion: 5, outputPerMillion: 25)),
            ("opus-4-6", .init(inputPerMillion: 5, outputPerMillion: 25)),
            ("opus-4-5", .init(inputPerMillion: 5, outputPerMillion: 25)),
            ("opus", .init(inputPerMillion: 15, outputPerMillion: 75)),
            ("haiku-4-5", .init(inputPerMillion: 1, outputPerMillion: 5)),
            ("haiku-3-5", .init(inputPerMillion: 0.80, outputPerMillion: 4)),
            ("sonnet", .init(inputPerMillion: 3, outputPerMillion: 15)),
            ("haiku", .init(inputPerMillion: 0.25, outputPerMillion: 1.25))
        ],
        .groq: [
            ("gpt-oss-120b", .init(inputPerMillion: 0.15, outputPerMillion: 0.60)),
            ("gpt-oss-20b", .init(inputPerMillion: 0.075, outputPerMillion: 0.30))
        ],
        .openai: [
            ("gpt-5.5", .init(inputPerMillion: 5.00, outputPerMillion: 30.00)),
            ("gpt-5.4-mini", .init(inputPerMillion: 0.75, outputPerMillion: 4.50)),
            ("gpt-5.4", .init(inputPerMillion: 2.50, outputPerMillion: 15.00)),
            ("gpt-5.2-pro", .init(inputPerMillion: 21.00, outputPerMillion: 168.00)),
            ("gpt-5.2", .init(inputPerMillion: 1.75, outputPerMillion: 14)),
            ("gpt-5-pro", .init(inputPerMillion: 15.00, outputPerMillion: 120.00)),
            ("gpt-5-mini", .init(inputPerMillion: 0.25, outputPerMillion: 2)),
            ("gpt-5-nano", .init(inputPerMillion: 0.05, outputPerMillion: 0.40)),
            ("gpt-5", .init(inputPerMillion: 1.25, outputPerMillion: 10)),
            ("gpt-4.1-mini", .init(inputPerMillion: 0.40, outputPerMillion: 1.60)),
            ("gpt-4.1-nano", .init(inputPerMillion: 0.10, outputPerMillion: 0.40)),
            ("gpt-4.1", .init(inputPerMillion: 2, outputPerMillion: 8)),
            ("gpt-4o-mini", .init(inputPerMillion: 0.15, outputPerMillion: 0.60)),
            ("gpt-4o", .init(inputPerMillion: 2.50, outputPerMillion: 10))
        ],
        .openrouter: []
    ]

    static func pricing(provider: ProviderKind, modelID: String) -> ModelPricing? {
        let key = PricingStore.key(provider: provider, model: modelID)
        if let value = exact[key] { return value }
        let normalized = modelID.lowercased()
        return patterns[provider]?.first { normalized.contains($0.0) }?.1
    }
}
