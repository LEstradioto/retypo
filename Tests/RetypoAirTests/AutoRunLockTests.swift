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
        return AppState(settings: settings)
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
