import Foundation

/// Sizes `max_output_tokens` for the Responses API, and explains an empty answer.
///
/// On reasoning models (gpt-5*, o-series) hidden reasoning tokens are drawn
/// from `max_output_tokens` before the message is written. A 512-token budget
/// sized for a typo fix comes back as `status: "incomplete"` with
/// `incomplete_details.reason == "max_output_tokens"` and an output array
/// holding nothing but a reasoning item.
enum OpenAIBudget {
    /// `low` is the only sub-default effort every current reasoning model
    /// accepts: `minimal` is rejected by gpt-5.1 and gpt-5.2.
    static let reasoningEffort = "low"

    private static let reasoningHeadroom = 4_000

    static func maxOutputTokens(for request: LLMRequest) -> Int {
        guard ModelParameterSupport.openAIUsesReasoning(request.model) else { return request.maxTokens }
        return request.maxTokens + reasoningHeadroom
    }

    static func emptyReason(_ object: [String: Any]) -> String {
        let details = object["incomplete_details"] as? [String: Any]
        if let reason = details?["reason"] as? String {
            return reason == "max_output_tokens" ? "spent the whole token budget on reasoning" : reason
        }
        return "status: \(object["status"] as? String ?? "unknown")"
    }
}
