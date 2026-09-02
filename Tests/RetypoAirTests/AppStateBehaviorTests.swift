import XCTest
@testable import RetypoAir

@MainActor
final class MockPanelHost: PanelHost {
    var hideRequestCount = 0
    var settingsRequestCount = 0
    var alwaysOnTop: Bool?
    var candidatesVisibilityHistory: [Bool] = []
    var importConfirmationHistory: [Bool] = []
    var freeformPromptHistory: [Bool] = []

    func setAlwaysOnTop(_ enabled: Bool) { alwaysOnTop = enabled }
    func requestHide() { hideRequestCount += 1 }
    func requestSettings() { settingsRequestCount += 1 }
    func setCandidatesVisible(_ visible: Bool) { candidatesVisibilityHistory.append(visible) }
    func setImportConfirmationVisible(_ visible: Bool) { importConfirmationHistory.append(visible) }
    func setFreeformPromptVisible(_ visible: Bool) { freeformPromptHistory.append(visible) }
}

@MainActor
final class AppStateBehaviorTests: XCTestCase {
    private func makeState(
        draftPersistence: RecordingDraftPersistence = RecordingDraftPersistence(),
        settingsPersistence: RecordingSettingsPersistence = RecordingSettingsPersistence()
    ) -> (AppState, MockPanelHost) {
        let state = AppState(
            settings: RetypoSettings(),
            draftPersistence: draftPersistence,
            settingsPersistence: settingsPersistence
        )
        let host = MockPanelHost()
        state.host = host
        return (state, host)
    }

    func testRequestHideForwardsToHost() {
        let (state, host) = makeState()
        state.requestHide()
        XCTAssertEqual(host.hideRequestCount, 1)
    }

    func testRequestSettingsForwardsToHost() {
        let (state, host) = makeState()
        state.requestSettings()
        XCTAssertEqual(host.settingsRequestCount, 1)
    }

    func testSetCandidateOverlayVisibleNotifiesHost() {
        let (state, host) = makeState()
        state.setCandidateOverlayVisible(true)
        XCTAssertEqual(host.candidatesVisibilityHistory, [true])
        state.setCandidateOverlayVisible(false)
        XCTAssertEqual(host.candidatesVisibilityHistory, [true, false])
    }

    func testCancelPendingImportNotifiesHost() {
        let (state, host) = makeState()
        state.pendingImport = PendingImport(text: "x", source: "Test")
        state.cancelPendingImport()
        XCTAssertNil(state.pendingImport)
        XCTAssertEqual(host.importConfirmationHistory, [false])
    }

    func testConfirmPendingImportWithoutPendingIsNoop() {
        let (state, host) = makeState()
        state.confirmPendingImport()
        XCTAssertEqual(host.importConfirmationHistory, [])
    }

    func testConfirmPendingImportPersistsWithoutTouchingLiveDraft() {
        let draftPersistence = RecordingDraftPersistence()
        let (state, host) = makeState(draftPersistence: draftPersistence)
        state.pendingImport = PendingImport(text: "Paste me", source: "Clipboard")

        state.confirmPendingImport()

        XCTAssertEqual(state.inputText, "Paste me")
        XCTAssertEqual(draftPersistence.savedTexts, ["Paste me"])
        XCTAssertEqual(host.importConfirmationHistory, [false])
    }

    func testStateLoadsDraftFromInjectedPersistence() {
        let draftPersistence = RecordingDraftPersistence(storedText: "Recovered")

        let (state, _) = makeState(draftPersistence: draftPersistence)

        XCTAssertEqual(state.inputText, "Recovered")
    }

    func testRestoreDraftSnapshotUsesInjectedPersistence() {
        let draftPersistence = RecordingDraftPersistence()
        let (state, _) = makeState(draftPersistence: draftPersistence)
        let snapshot = DraftSnapshot(text: "Earlier draft")

        state.restoreDraftSnapshot(snapshot)

        XCTAssertEqual(state.inputText, "Earlier draft")
        XCTAssertEqual(draftPersistence.savedTexts, ["Earlier draft"])
        XCTAssertEqual(state.status, "Draft restored")
    }

    func testExternalImportAlwaysWaitsForConfirmation() {
        let (state, _) = makeState()
        state.inputText = ""

        XCTAssertTrue(state.receiveExternalImport("Clipboard text", source: "Safari"))
        XCTAssertEqual(state.pendingImport?.text, "Clipboard text")
        XCTAssertEqual(state.pendingImport?.source, "Safari")
        XCTAssertEqual(state.inputText, "")
    }

    func testMatchingExternalImportStillWaitsForConfirmation() {
        let (state, _) = makeState()
        state.inputText = "Same text"

        XCTAssertTrue(state.receiveExternalImport("Same text", source: "TextEdit"))
        XCTAssertEqual(state.pendingImport?.text, "Same text")
    }

    /// Regression for the ESC-in-candidates fix: clearCandidateResults wipes
    /// state but does NOT ask the host to hide the panel.
    func testClearCandidateResultsDoesNotHideOverlay() {
        let (state, host) = makeState()
        state.candidateResults = [
            CandidateResult(action: EditAction.defaults[0], output: "x", diff: "− \n+ x", usage: .zero, costUSD: nil)
        ]
        state.selectedCandidateIndex = 0
        state.clearCandidateResults()
        XCTAssertTrue(state.candidateResults.isEmpty)
        XCTAssertEqual(state.selectedCandidateIndex, 0)
        // Host should not be asked to hide — that's the ESC→launcher behavior.
        XCTAssertEqual(host.hideRequestCount, 0)
        XCTAssertEqual(host.candidatesVisibilityHistory, [])
    }

    func testToggleCandidateOverlayWithEmptyDiffIsNoop() {
        let (state, host) = makeState()
        state.diffText = ""
        state.toggleCandidateOverlay()
        // candidateResults still empty, but overlay state toggled.
        XCTAssertEqual(host.candidatesVisibilityHistory, [true])
        XCTAssertTrue(state.candidateResults.isEmpty)
    }

    func testHostIsWeaklyHeld() {
        let state = AppState(
            settings: RetypoSettings(),
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: RecordingSettingsPersistence()
        )
        do {
            let host = MockPanelHost()
            state.host = host
            XCTAssertNotNil(state.host)
        }
        // host has gone out of scope; weak ref nils out.
        XCTAssertNil(state.host)
    }
}
