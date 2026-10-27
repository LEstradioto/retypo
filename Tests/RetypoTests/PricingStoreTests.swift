import XCTest
@testable import Retypo

final class PricingStoreTests: XCTestCase {
    func testKeyFormatJoinsProviderAndModel() {
        XCTAssertEqual(PricingStore.key(provider: .openai, model: "gpt-5"), "openai::gpt-5")
        XCTAssertEqual(PricingStore.key(provider: .anthropic, model: "claude-opus-4-7"), "anthropic::claude-opus-4-7")
    }

    func testKeysAreStableForExactDefaults() {
        for (key, _) in DefaultPricing.exact {
            XCTAssertTrue(key.contains("::"))
            XCTAssertFalse(key.hasPrefix("::"))
            XCTAssertFalse(key.hasSuffix("::"))
        }
    }

    func testTokenUsageTotalSums() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 250)
        XCTAssertEqual(usage.totalTokens, 350)
    }

    func testTokenUsageZero() {
        XCTAssertEqual(TokenUsage.zero.totalTokens, 0)
    }

    func testModelPricingZero() {
        XCTAssertEqual(ModelPricing.zero.inputPerMillion, 0)
        XCTAssertEqual(ModelPricing.zero.outputPerMillion, 0)
    }

    func testCostSnapshotPreservesUsage() {
        let snap = CostSnapshot(usage: TokenUsage(inputTokens: 10, outputTokens: 20), costUSD: 0.42)
        XCTAssertEqual(snap.usage.totalTokens, 30)
        XCTAssertEqual(snap.costUSD, 0.42)
    }

    func testHistoryEntryEncodesAndDecodes() throws {
        let entry = HistoryEntry(
            provider: .openai,
            model: "gpt-5",
            actionID: "correct",
            actionTitle: "Correct",
            input: "ths is a test",
            output: "this is a test",
            diff: "− ths\n+ this",
            usage: TokenUsage(inputTokens: 5, outputTokens: 4),
            costUSD: 0.0001
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        XCTAssertEqual(decoded.input, entry.input)
        XCTAssertEqual(decoded.usage.totalTokens, 9)
    }
}
