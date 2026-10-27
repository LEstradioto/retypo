import XCTest
@testable import Retypo

/// Reasoning/thinking tokens are drawn from the output budget before any
/// visible text, so a budget sized for the answer alone returned an empty
/// completion — reported as the useless "Invalid API response".
final class TokenBudgetTests: XCTestCase {
    private func request(model: String, maxTokens: Int) -> LLMRequest {
        LLMRequest(provider: .anthropic, model: model, system: "s", user: "u", maxTokens: maxTokens)
    }

    func testAnthropicThinkingModelsGetHeadroom() {
        let budget = AnthropicBudget.maxTokens(for: request(model: "claude-opus-5", maxTokens: 512))
        XCTAssertGreaterThan(budget, 512)
    }

    func testAnthropicNonThinkingModelsKeepTheRequestedBudget() {
        let budget = AnthropicBudget.maxTokens(for: request(model: "claude-haiku-4-5-20251001", maxTokens: 512))
        XCTAssertEqual(budget, 512)
    }

    func testAnthropicBudgetStaysUnderTheOutputCeiling() {
        let budget = AnthropicBudget.maxTokens(for: request(model: "claude-opus-5", maxTokens: 120_000))
        XCTAssertLessThanOrEqual(budget, 64_000)
    }

    func testAnthropicExplainsABudgetExhaustedByReasoning() {
        let reason = AnthropicBudget.emptyReason(["stop_reason": "max_tokens"])
        XCTAssertEqual(reason, "spent the whole token budget on reasoning")
        XCTAssertEqual(AnthropicBudget.emptyReason(["stop_reason": "refusal"]), "stop reason: refusal")
        XCTAssertEqual(AnthropicBudget.emptyReason([:]), "no content returned")
    }

    func testOpenAIReasoningModelsGetHeadroom() {
        let reasoning = LLMRequest(provider: .openai, model: "gpt-5", system: "s", user: "u", maxTokens: 512)
        let chat = LLMRequest(provider: .openai, model: "gpt-4o", system: "s", user: "u", maxTokens: 512)
        XCTAssertGreaterThan(OpenAIBudget.maxOutputTokens(for: reasoning), 512)
        XCTAssertEqual(OpenAIBudget.maxOutputTokens(for: chat), 512)
    }

    /// gpt-5.1 and gpt-5.2 reject `minimal`; `low` is accepted everywhere.
    func testOpenAIReasoningEffortIsTheUniversallyAcceptedLevel() {
        XCTAssertEqual(OpenAIBudget.reasoningEffort, "low")
    }

    func testOpenAIExplainsAnIncompleteResponse() {
        let object: [String: Any] = ["status": "incomplete", "incomplete_details": ["reason": "max_output_tokens"]]
        XCTAssertEqual(OpenAIBudget.emptyReason(object), "spent the whole token budget on reasoning")
        XCTAssertEqual(OpenAIBudget.emptyReason(["status": "failed"]), "status: failed")
    }
}
