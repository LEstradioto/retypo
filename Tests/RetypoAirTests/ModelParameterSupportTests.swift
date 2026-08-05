import XCTest
@testable import RetypoAir

/// Regression cover for the "some models work, others don't" bug: the app sent
/// `temperature` to every Anthropic and OpenAI model, and the newer ones answer
/// 400 ("`temperature` is deprecated for this model").
final class ModelParameterSupportTests: XCTestCase {
    func testAnthropicModelsThatStillAcceptTemperature() {
        for model in ["claude-haiku-4-5-20251001", "claude-sonnet-4-5-20250929", "claude-opus-4-5-20251101",
                      "claude-opus-4-6", "claude-sonnet-4-6", "claude-3-5-sonnet-20241022"] {
            XCTAssertTrue(ModelParameterSupport.anthropicAcceptsTemperature(model), model)
        }
    }

    func testAnthropicModelsThatRejectTemperature() {
        for model in ["claude-opus-5", "claude-sonnet-5", "claude-fable-5", "claude-opus-4-8", "claude-opus-4-7"] {
            XCTAssertFalse(ModelParameterSupport.anthropicAcceptsTemperature(model), model)
        }
    }

    /// Unknown ids are assumed to be newer than the last model we knew about.
    func testUnknownAnthropicModelIsTreatedAsNewGeneration() {
        XCTAssertFalse(ModelParameterSupport.anthropicAcceptsTemperature("claude-opus-9"))
        XCTAssertTrue(ModelParameterSupport.anthropicThinksByDefault("claude-opus-9"))
    }

    func testThinkingByDefaultTracksTheSameGeneration() {
        XCTAssertTrue(ModelParameterSupport.anthropicThinksByDefault("claude-opus-5"))
        XCTAssertFalse(ModelParameterSupport.anthropicThinksByDefault("claude-haiku-4-5-20251001"))
    }

    func testOpenAIReasoningModels() {
        for model in ["gpt-5", "gpt-5.2", "gpt-5-mini", "o1", "o3-mini", "o4-mini"] {
            XCTAssertTrue(ModelParameterSupport.openAIUsesReasoning(model), model)
        }
    }

    func testOpenAIChatModelsAreNotReasoning() {
        for model in ["gpt-4o", "gpt-4.1-mini", "gpt-5-chat-latest", "gpt-5.2-chat-latest", "gpt-3.5-turbo"] {
            XCTAssertFalse(ModelParameterSupport.openAIUsesReasoning(model), model)
        }
    }

    /// `openrouter/olmo-2` must not be mistaken for the o-series.
    func testOSeriesPrefixDoesNotMatchUnrelatedNames() {
        XCTAssertFalse(ModelParameterSupport.openAIUsesReasoning("olmo-2"))
        XCTAssertFalse(ModelParameterSupport.openAIUsesReasoning("o1pro"))
    }
}
