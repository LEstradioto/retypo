import Foundation

/// Model choices for the CLI providers.
///
/// Neither CLI exposes a list endpoint, so these are curated. `default` sends
/// no model flag at all, letting the CLI's own configuration decide
/// (`~/.codex/config.toml`, or Claude Code's configured model) — which is also
/// the safe pick when a plan does not grant every model.
enum CLIModelCatalog {
    static let defaultModelID = "default"

    /// Aliases rather than dated ids: `claude --model` resolves them to the
    /// latest release, and availability depends on the subscription plan.
    static let claudeCode = models(["default", "haiku", "sonnet", "opus", "fable"])

    /// A ChatGPT account only reaches Codex-enabled models — plain API ids
    /// such as `gpt-5.2` are rejected with "not supported when using Codex
    /// with a ChatGPT account".
    static let codex = models(["default", "gpt-5.6-sol", "gpt-5.6-luna", "gpt-5.6-terra"])

    /// `nil` when the selection means "whatever the CLI is configured to use".
    static func explicitModel(_ model: String) -> String? {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != defaultModelID else { return nil }
        return trimmed
    }

    private static func models(_ ids: [String]) -> [ProviderModel] {
        ids.map { ProviderModel(id: $0) }
    }
}
