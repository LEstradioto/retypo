import XCTest
@testable import RetypoAir

/// Auto-run fires on every typing pause. Against a CLI provider that is ~7s
/// and thousands of subscription tokens per pause, so it stays off there.
@MainActor
final class AutoRunLockTests: XCTestCase {
    private func makeState(provider: ProviderKind, autoCorrect: Bool) -> AppState {
        var settings = RetypoSettings()
        settings.provider = provider
        settings.autoCorrect = autoCorrect
        return AppState(settings: settings, draftPersistence: RecordingDraftPersistence())
    }

    func testAutoRunFollowsThePreferenceForAPIProviders() {
        XCTAssertTrue(makeState(provider: .anthropic, autoCorrect: true).autoRunEnabled)
        XCTAssertFalse(makeState(provider: .anthropic, autoCorrect: false).autoRunEnabled)
    }

    func testAutoRunStaysOffForCLIProvidersEvenWhenEnabled() {
        XCTAssertFalse(makeState(provider: .claudeCode, autoCorrect: true).autoRunEnabled)
        XCTAssertFalse(makeState(provider: .codex, autoCorrect: true).autoRunEnabled)
    }

    /// Turning the toggle on against a CLI provider has to say why nothing
    /// happens, otherwise the footer just reads "Manual" with no explanation.
    func testTogglingAutoRunOnACLIProviderExplainsItself() {
        let state = makeState(provider: .claudeCode, autoCorrect: false)
        state.toggleAutoRun()
        XCTAssertTrue(state.settings.autoCorrect)
        XCTAssertFalse(state.autoRunEnabled)
        XCTAssertTrue(state.status.contains("Claude Code"), state.status)
    }

    func testTogglingAutoRunOnAnAPIProviderKeepsTheStatusAlone() {
        let state = makeState(provider: .anthropic, autoCorrect: false)
        state.status = "Ready"
        state.toggleAutoRun()
        XCTAssertTrue(state.autoRunEnabled)
        XCTAssertEqual(state.status, "Ready")
    }
}

/// The cost readout for a subscription run: "$—" looked like the pricing
/// table had failed to load.
@MainActor
final class SubscriptionCostLabelTests: XCTestCase {
    private func tracker() -> CostTracker {
        CostTracker(initialPricing: ["anthropic::claude-haiku-4-5": .init(inputPerMillion: 1, outputPerMillion: 5)], initialUsageLedger: [])
    }

    func testCLIRunIsLabelledAsCoveredByThePlan() {
        let cost = tracker()
        cost.recordUsage(provider: .claudeCode, model: "haiku", usage: TokenUsage(inputTokens: 11_000, outputTokens: 180))
        XCTAssertTrue(cost.lastCostIsSubscription)
        XCTAssertEqual(cost.lastCostLabel, "subscription")
    }

    func testPricedRunKeepsItsAmount() {
        let cost = tracker()
        cost.recordUsage(provider: .anthropic, model: "claude-haiku-4-5", usage: TokenUsage(inputTokens: 1_000_000, outputTokens: 0))
        XCTAssertFalse(cost.lastCostIsSubscription)
        XCTAssertEqual(cost.lastCostLabel, "$1.0000")
    }

    /// Someone who fills in pricing for a CLI model asked for that estimate.
    func testPricedCLIModelShowsTheEstimateInstead() {
        let cost = CostTracker(initialPricing: ["claudeCode::opus": .init(inputPerMillion: 5, outputPerMillion: 25)], initialUsageLedger: [])
        cost.recordUsage(provider: .claudeCode, model: "opus", usage: TokenUsage(inputTokens: 1_000_000, outputTokens: 0))
        XCTAssertFalse(cost.lastCostIsSubscription)
        XCTAssertEqual(cost.lastCostLabel, "$5.0000")
    }

    /// An API run after a CLI run must not inherit the plan label.
    func testLabelFollowsTheMostRecentRun() {
        let cost = tracker()
        cost.recordUsage(provider: .codex, model: "default", usage: TokenUsage(inputTokens: 16_000, outputTokens: 14))
        cost.recordUsage(provider: .anthropic, model: "claude-haiku-4-5", usage: TokenUsage(inputTokens: 1_000_000, outputTokens: 0))
        XCTAssertFalse(cost.lastCostIsSubscription)
    }
}
