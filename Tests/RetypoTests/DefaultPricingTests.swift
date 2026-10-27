import XCTest
@testable import Retypo

final class DefaultPricingTests: XCTestCase {
    func testExactKeyMatchReturnsListedPricing() {
        let result = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-opus-4-7")
        XCTAssertEqual(result?.inputPerMillion, 5)
        XCTAssertEqual(result?.outputPerMillion, 25)
    }

    func testAnthropicOpusOldVersionFallsBackToHigherTier() {
        let result = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-opus-4-1")
        XCTAssertEqual(result?.inputPerMillion, 15)
        XCTAssertEqual(result?.outputPerMillion, 75)
    }

    func testAnthropicSonnetMatchByPattern() {
        let result = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-sonnet-99-future")
        XCTAssertEqual(result?.inputPerMillion, 3)
        XCTAssertEqual(result?.outputPerMillion, 15)
    }

    func testGroqGptOss20bMatchesExpectedRate() {
        let result = DefaultPricing.pricing(provider: .groq, modelID: "openai/gpt-oss-20b-distilled")
        XCTAssertEqual(result?.inputPerMillion, 0.075)
        XCTAssertEqual(result?.outputPerMillion, 0.30)
    }

    func testOpenAIMiniMatchesBeforeBaseModel() {
        let result = DefaultPricing.pricing(provider: .openai, modelID: "gpt-5-mini-future")
        XCTAssertEqual(result?.inputPerMillion, 0.25)
        XCTAssertEqual(result?.outputPerMillion, 2)
    }

    func testOpenrouterReturnsNil() {
        XCTAssertNil(DefaultPricing.pricing(provider: .openrouter, modelID: "any-model"))
    }

    func testUnknownAnthropicReturnsNil() {
        XCTAssertNil(DefaultPricing.pricing(provider: .anthropic, modelID: "claude-something-totally-new"))
    }

    func testHaikuVersionMatchesBeforeBaseHaiku() {
        let v45 = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-haiku-4-5-future")
        XCTAssertEqual(v45?.inputPerMillion, 1)
        let v35 = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-haiku-3-5-future")
        XCTAssertEqual(v35?.inputPerMillion, 0.80)
        let base = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-haiku-old")
        XCTAssertEqual(base?.inputPerMillion, 0.25)
    }

    func testGptOss120bMatchesBefore20b() {
        let big = DefaultPricing.pricing(provider: .groq, modelID: "openai/gpt-oss-120b")
        XCTAssertEqual(big?.inputPerMillion, 0.15)
        let small = DefaultPricing.pricing(provider: .groq, modelID: "openai/gpt-oss-20b")
        XCTAssertEqual(small?.inputPerMillion, 0.075)
    }

    func testExactKeyFormatRoundTrip() {
        let key = PricingStore.key(provider: .openai, model: "gpt-4o")
        XCTAssertNotNil(DefaultPricing.exact[key])
    }
}
