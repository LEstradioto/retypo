import XCTest
@testable import RetypoAir

/// One shortcut may belong to exactly one owner. Assigning a taken combo is
/// rejected with the owner's name; the old value is kept.
@MainActor
final class ShortcutConflictTests: XCTestCase {
    private func makeState() -> AppState {
        AppState(
            settings: RetypoSettings(),
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: RecordingSettingsPersistence()
        )
    }

    func testFreeShortcutHasNoOwner() {
        XCTAssertNil(makeState().shortcutOwner("cmd+ctrl+opt+x"))
    }

    func testModeShortcutIsOwned() {
        let state = makeState()
        XCTAssertEqual(state.shortcutOwner("cmd+1"), "mode “Correct”")
    }

    func testClaimRejectsTakenShortcutAndKeepsOld() {
        let state = makeState()
        let improveID = state.actions.first(where: { $0.title == "Improve Writing" })?.id ?? "improve"
        let error = state.claimActionShortcut("cmd+1", for: improveID)
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("Correct") == true)
        XCTAssertNotEqual(state.settings.shortcutByAction[improveID], "cmd+1")
    }

    func testClaimAcceptsFreeShortcut() {
        let state = makeState()
        let error = state.claimActionShortcut("cmd+ctrl+opt+x", for: "improve")
        XCTAssertNil(error)
        XCTAssertEqual(state.settings.shortcutByAction["improve"], "cmd+ctrl+opt+x")
    }

    func testClaimingOwnShortcutAgainPasses() {
        let state = makeState()
        XCTAssertNil(state.claimActionShortcut("cmd+1", for: "correct"))
    }

    func testEmptyShortcutClears() {
        let state = makeState()
        XCTAssertNil(state.claimActionShortcut("", for: "correct"))
        XCTAssertEqual(state.settings.shortcutByAction["correct"], "")
    }

    func testModelNavigationShortcutsAreOwned() {
        let state = makeState()
        XCTAssertEqual(state.shortcutOwner("cmd+opt+]"), "Next model")
        XCTAssertNotNil(state.claimActionShortcut("cmd+opt+]", for: "improve"))
    }

    func testSmartPasteShortcutIsOwnedAndClaimable() {
        let state = makeState()
        XCTAssertEqual(state.shortcutOwner("cmd+shift+v"), "Smart paste")
        XCTAssertNotNil(state.claimActionShortcut("cmd+shift+v", for: "improve"))
        XCTAssertNil(state.claimSmartPasteShortcut("cmd+ctrl+opt+p"))
        XCTAssertEqual(state.settings.smartPasteShortcut, "cmd+ctrl+opt+p")
    }

    func testHeaderModeNavigationWrapsAndSelects() {
        let state = makeState()
        let count = state.enabledActions.count
        XCTAssertGreaterThan(count, 1)
        state.headerModeIndex = count - 1
        state.nextHeaderMode()
        XCTAssertEqual(state.headerModeIndex, 0)
        XCTAssertEqual(state.settings.currentActionID, state.enabledActions[0].id)
        state.previousHeaderMode()
        XCTAssertEqual(state.headerModeIndex, count - 1)
    }

    func testToggleModePickerIgnoresCandidateResults() {
        let state = makeState()
        state.candidateResults = [
            CandidateResult(action: EditAction.defaults[0], output: "x", diff: "d", usage: .zero, costUSD: nil)
        ]
        state.toggleModePicker()
        XCTAssertTrue(state.headerModePickerVisible)
        XCTAssertFalse(state.showCandidateOverlay)
    }

    func testToggleModePickerOpensHeaderWhenNoResults() {
        let state = makeState()
        state.toggleModePicker()
        XCTAssertTrue(state.headerModePickerVisible)
        XCTAssertEqual(state.headerModeIndex, state.enabledActions.firstIndex(where: { $0.id == state.currentAction.id }))
        state.toggleModePicker()
        XCTAssertFalse(state.headerModePickerVisible)
    }
}
