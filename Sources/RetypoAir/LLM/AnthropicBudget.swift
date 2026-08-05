import Foundation

/// Sizes `max_tokens` for Anthropic requests, and explains an empty answer.
///
/// From Opus 4.7 / Sonnet 5 onward adaptive thinking is on by default and the
/// thinking tokens are drawn from `max_tokens` *before* any visible text. A
/// budget sized for the answer alone (the editor asks for as little as 512)
/// comes back as a thinking block, `stop_reason: "max_tokens"`, and no text —
/// which used to surface as the useless "Invalid API response".
enum AnthropicBudget {
    /// Room for the model to think before it starts answering. Unused headroom
    /// is free: Anthropic bills generated tokens, not the ceiling.
    private static let thinkingHeadroom = 8_000
    private static let outputCeiling = 64_000

    static func maxTokens(for request: LLMRequest) -> Int {
        guard ModelParameterSupport.anthropicThinksByDefault(request.model) else { return request.maxTokens }
        return min(outputCeiling, request.maxTokens + thinkingHeadroom)
    }

    static func emptyReason(_ object: [String: Any]) -> String {
        guard let stop = object["stop_reason"] as? String else { return "no content returned" }
        if stop == "max_tokens" { return "spent the whole token budget on reasoning" }
        return "stop reason: \(stop)"
    }
}
