import XCTest
@testable import RetypoAir

final class ModelsDevPricingTests: XCTestCase {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testMapsCostsToProviderModelKeys() throws {
        let parsed = try ModelsDevPricing.pricingByKey(from: data("""
        {"openai": {"models": {"gpt-5-mini": {"cost": {"input": 0.25, "output": 2}}}}}
        """))
        XCTAssertEqual(parsed["openai::gpt-5-mini"], ModelPricing(inputPerMillion: 0.25, outputPerMillion: 2))
    }

    func testSkipsModelsWithoutCost() throws {
        let parsed = try ModelsDevPricing.pricingByKey(from: data("""
        {"groq": {"models": {"whisper-large-v3": {"limit": {"context": 8000}}}}}
        """))
        XCTAssertTrue(parsed.isEmpty)
    }

    func testSkipsProvidersWithNoProviderKind() throws {
        let parsed = try ModelsDevPricing.pricingByKey(from: data("""
        {"some-future-cloud": {"models": {"x-1": {"cost": {"input": 1, "output": 2}}}}}
        """))
        XCTAssertTrue(parsed.isEmpty)
    }

    func testSkipsPartialCostObjects() throws {
        let parsed = try ModelsDevPricing.pricingByKey(from: data("""
        {"anthropic": {"models": {"half": {"cost": {"input": 3}}}}}
        """))
        XCTAssertTrue(parsed.isEmpty)
    }

    func testMergeFillsMissingKeysWithoutClobbering() {
        let merged = CostTracker.mergingFetchedPricing(
            [
                "openai::gpt-5-mini": .init(inputPerMillion: 0.25, outputPerMillion: 2),
                "openai::gpt-5-nano": .init(inputPerMillion: 0.05, outputPerMillion: 0.4)
            ],
            into: ["openai::gpt-5-mini": .init(inputPerMillion: 9, outputPerMillion: 9)]
        )
        XCTAssertEqual(merged.inserted, 1)
        XCTAssertEqual(merged.pricing["openai::gpt-5-mini"]?.inputPerMillion, 9)
        XCTAssertEqual(merged.pricing["openai::gpt-5-nano"]?.inputPerMillion, 0.05)
    }
}
