import AppKit
import XCTest
@testable import Retypo

@MainActor
final class PanelFramePersistenceTests: XCTestCase {
    func testRapidFrameUpdatesPersistOnlyTheFinalFrameOnFlush() {
        let settingsPersistence = RecordingSettingsPersistence()
        let state = makeState(settingsPersistence: settingsPersistence)

        for eventIndex in 1 ... 200 {
            state.updatePanelFrame(NSRect(x: eventIndex, y: 20, width: 760, height: 500))
        }
        XCTAssertTrue(settingsPersistence.savedSettings.isEmpty)

        state.flushPendingPanelFrame()

        XCTAssertEqual(settingsPersistence.savedSettings.count, 1)
        XCTAssertEqual(settingsPersistence.savedSettings.last?.panelFrame.x, 200)
        XCTAssertFalse(state.panelFrameSavePending)
    }

    func testUnchangedFrameDoesNotSchedulePersistence() {
        let settings = RetypoSettings()
        let settingsPersistence = RecordingSettingsPersistence()
        let state = AppState(
            settings: settings,
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: settingsPersistence
        )

        state.updatePanelFrame(settings.panelFrame.nsRect)
        state.flushPendingPanelFrame()

        XCTAssertTrue(settingsPersistence.savedSettings.isEmpty)
    }

    private func makeState(settingsPersistence: RecordingSettingsPersistence) -> AppState {
        AppState(
            settings: RetypoSettings(),
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: settingsPersistence
        )
    }
}
