import Foundation

/// Which optional request parameters a given model still accepts.
///
/// The providers have split on this and keep moving:
/// - Anthropic returns 400 "`temperature` is deprecated for this model" on
///   Opus 4.7/4.8, Sonnet 5, Opus 5 and Fable 5, while Haiku 4.5 and the
///   4.5/4.6 families still accept it.
/// - OpenAI returns 400 "Unsupported parameter: 'temperature'" on reasoning
///   models (gpt-5*, o-series) and 400 on `reasoning.effort` for the older
///   chat models.
///
/// A hardcoded table rots with every release, so these are first guesses only:
/// a wrong guess is corrected at runtime by `RejectedParameterMemory`.
enum ModelParameterSupport {
    /// Anthropic families that still accept sampling parameters. Anything
    /// newer — or unrecognised — is assumed to reject them, because that is
    /// the direction the API keeps moving.
    private static let anthropicSamplingFamilies = [
        "claude-2", "claude-3",
        "claude-opus-4-0", "claude-opus-4-1", "claude-opus-4-5", "claude-opus-4-6",
        "claude-sonnet-4-0", "claude-sonnet-4-5", "claude-sonnet-4-6",
        "claude-haiku-3", "claude-haiku-4-5"
    ]

    static func anthropicAcceptsTemperature(_ model: String) -> Bool {
        let id = model.lowercased()
        return anthropicSamplingFamilies.contains { id.hasPrefix($0) }
    }

    /// The same generation that dropped sampling parameters also turned
    /// adaptive thinking on by default, and thinking tokens are drawn from
    /// `max_tokens` before any visible text is emitted.
    static func anthropicThinksByDefault(_ model: String) -> Bool {
        !anthropicAcceptsTemperature(model)
    }

    /// OpenAI reasoning models reject `temperature` and spend
    /// `max_output_tokens` on hidden reasoning before the first visible token.
    /// `*-chat-*` variants of the same family are plain chat models.
    static func openAIUsesReasoning(_ model: String) -> Bool {
        let id = model.lowercased()
        if id.contains("chat") { return false }
        if id.hasPrefix("gpt-5") || id.hasPrefix("gpt-6") { return true }
        return ["o1", "o3", "o4", "o5"].contains { id == $0 || id.hasPrefix("\($0)-") }
    }
}
