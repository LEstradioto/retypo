import XCTest
@testable import Retypo

@MainActor
final class ChangeReviewStateTests: XCTestCase {
    private func makeState() -> (AppState, MockPanelHost) {
        var settings = RetypoSettings()
        settings.autoCopy = false
        let state = AppState(settings: settings, draftPersistence: RecordingDraftPersistence(), settingsPersistence: RecordingSettingsPersistence())
        let host = MockPanelHost()
        state.host = host
        return (state, host)
    }

    private func run(_ state: AppState, from original: String, to text: String) {
        state.inputText = original
        state.applyResult(AppState.ActionOutcome(
            text: text, original: original, changed: true,
            response: LLMResponse(text: text), action: EditAction.defaults[0], instruction: ""
        ))
    }

    func testARunMarksItsEdits() {
        let (state, _) = makeState()
        run(state, from: "a estimativa de economia apresentada", to: "a estimativa apresentada")
        XCTAssertEqual(state.inlineChanges.marks.removals.count, 1)
        XCTAssertEqual(state.wordsChangedLast, 1)
    }

    func testTypingRetiresTheMarksAndTheReview() {
        let (state, _) = makeState()
        run(state, from: "the cat sat", to: "the dog sat")
        state.toggleChangeReview()
        XCTAssertTrue(state.isReviewingChanges)
        state.inputText = "the dog sat!"
        XCTAssertFalse(state.inlineChanges.hasEdits)
        XCTAssertFalse(state.isReviewingChanges)
        XCTAssertEqual(state.wordsChangedLast, 1, "Δ still reports the last run")
    }

    func testReviewNeedsEdits() {
        let (state, _) = makeState()
        run(state, from: "same text", to: "same text")
        state.toggleChangeReview()
        XCTAssertFalse(state.isReviewingChanges)
    }

    func testEscapeLeavesTheReviewBeforeHidingThePanel() {
        let (state, host) = makeState()
        run(state, from: "the cat sat", to: "the dog sat")
        state.toggleChangeReview()
        state.cancelFromEditor()
        XCTAssertFalse(state.isReviewingChanges)
        XCTAssertEqual(host.hideRequestCount, 0)
        state.cancelFromEditor()
        XCTAssertEqual(host.hideRequestCount, 1)
    }

    func testShiftCmdDTogglesTheReviewAndOwnsTheCombo() {
        let (state, _) = makeState()
        run(state, from: "the cat sat", to: "the dog sat")
        XCTAssertTrue(state.handleShortcut("cmd+shift+d"))
        XCTAssertTrue(state.isReviewingChanges)
        XCTAssertTrue(state.handleShortcut("cmd+shift+d"))
        XCTAssertFalse(state.isReviewingChanges)
        XCTAssertEqual(state.shortcutOwner("cmd+shift+d"), "Show changes")
    }

    func testUndoBringsBackThePreviousRunsMarks() {
        let (state, _) = makeState()
        run(state, from: "the cat sat", to: "the dog sat")
        let first = state.inlineChanges
        run(state, from: "the dog sat", to: "the dog sat down")
        XCTAssertTrue(state.undoEditorChange())
        XCTAssertEqual(state.inputText, "the dog sat")
        XCTAssertEqual(state.inlineChanges, first)
    }

    func testAppliedCandidateMarksItsOwnEdits() {
        let (state, _) = makeState()
        state.inputText = "the cat sat"
        let changes = TextDiff(original: "the cat sat", revised: "the dog sat")
        state.candidateResults = [CandidateResult(action: EditAction.defaults[0], output: "the dog sat", diff: "", changes: changes, usage: .zero, costUSD: nil)]
        state.restoreSelectedCandidateToEditor()
        XCTAssertEqual(state.inlineChanges, changes)
        XCTAssertEqual(state.inputText, "the dog sat")
    }

    func testRestoringADraftDropsStaleMarks() {
        let (state, _) = makeState()
        run(state, from: "the cat sat", to: "the dog sat")
        state.restoreDraftSnapshot(DraftSnapshot(text: "an older draft"))
        XCTAssertFalse(state.inlineChanges.hasEdits)
    }
}
