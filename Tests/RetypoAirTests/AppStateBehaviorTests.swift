import AppKit
import XCTest
@testable import RetypoAir

@MainActor
final class MockPanelHost: PanelHost {
    var hideRequestCount = 0
    var settingsRequestCount = 0
    var alwaysOnTop: Bool?
    var candidatesVisibilityHistory: [Bool] = []
    var freeformPromptHistory: [Bool] = []
    var appearanceHistory: [NSAppearance?] = []
    var windowOpacityHistory: [Double] = []

    func setAlwaysOnTop(_ enabled: Bool) { alwaysOnTop = enabled }
    func requestHide() { hideRequestCount += 1 }
    func requestSettings() { settingsRequestCount += 1 }
    func setCandidatesVisible(_ visible: Bool) { candidatesVisibilityHistory.append(visible) }
    func setFreeformPromptVisible(_ visible: Bool) { freeformPromptHistory.append(visible) }
    func setPanelAppearance(_ appearance: NSAppearance?) { appearanceHistory.append(appearance) }
    func setWindowOpacity(_ opacity: Double) { windowOpacityHistory.append(opacity) }
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

    func testExternalImportStagesWithoutTouchingEditor() {
        let (state, _) = makeState()
        state.inputText = ""

        state.receiveExternalImport("Clipboard text", source: "Safari")

        XCTAssertEqual(state.stagedImport?.text, "Clipboard text")
        XCTAssertEqual(state.stagedImport?.source, "Safari")
        XCTAssertEqual(state.inputText, "")
    }

    func testMatchingExternalImportStillStages() {
        let (state, _) = makeState()
        state.inputText = "Same text"

        state.receiveExternalImport("Same text", source: "TextEdit")

        XCTAssertEqual(state.stagedImport?.text, "Same text")
        XCTAssertEqual(state.inputText, "Same text")
    }

    func testSmartPasteWritesStagedTextAndConsumesStage() {
        let (state, _) = makeState()
        state.inputText = ""
        state.receiveExternalImport("Staged words", source: "Safari")

        state.doSmartPaste()

        XCTAssertEqual(state.inputText, "Staged words")
        XCTAssertNil(state.stagedImport)
    }

    func testSmartPasteWithoutStageExplainsItself() {
        let (state, _) = makeState()
        state.inputText = "Keep me"

        state.doSmartPaste()

        XCTAssertEqual(state.inputText, "Keep me")
        XCTAssertTrue(state.status.contains("Nothing staged"), state.status)
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

    func testSetThemePersistsAndPushesAppearance() {
        let (state, host) = makeState()
        state.setTheme(.dark)
        XCTAssertEqual(state.settings.mainTheme, .dark)
        XCTAssertEqual(host.appearanceHistory.count, 1)
        XCTAssertEqual(host.appearanceHistory.first??.name, NSAppearance.Name.darkAqua)
        state.setTheme(.system)
        XCTAssertNil(host.appearanceHistory.last ?? NSAppearance(named: .darkAqua))
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
