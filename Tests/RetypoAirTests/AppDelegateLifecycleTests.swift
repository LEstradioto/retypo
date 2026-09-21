import AppKit
import XCTest
@testable import RetypoAir

@MainActor
final class AppDelegateLifecycleTests: XCTestCase {
    func testTerminationFlushesPendingPersistence() {
        let draftPersistence = RecordingDraftPersistence()
        let settingsPersistence = RecordingSettingsPersistence()
        let delegate = makeDelegate(
            draftPersistence: draftPersistence,
            settingsPersistence: settingsPersistence
        )
        delegate.state?.updatePanelFrame(NSRect(x: 10, y: 20, width: 760, height: 500))

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertEqual(draftPersistence.flushCount, 1)
        XCTAssertEqual(settingsPersistence.savedSettings.count, 1)
    }

    func testHidingPanelFlushesPendingPersistence() {
        let draftPersistence = RecordingDraftPersistence()
        let settingsPersistence = RecordingSettingsPersistence()
        let delegate = makeDelegate(
            draftPersistence: draftPersistence,
            settingsPersistence: settingsPersistence
        )
        delegate.state?.updatePanelFrame(NSRect(x: 10, y: 20, width: 760, height: 500))

        delegate.hidePanelAndFocusPrevious()

        XCTAssertEqual(draftPersistence.flushCount, 1)
        XCTAssertEqual(settingsPersistence.savedSettings.count, 1)
    }

    func testEndingLiveResizeFlushesPendingPanelFrame() {
        let settingsPersistence = RecordingSettingsPersistence()
        let delegate = makeDelegate(
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: settingsPersistence
        )
        delegate.state?.updatePanelFrame(NSRect(x: 10, y: 20, width: 760, height: 500))

        delegate.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification))

        XCTAssertEqual(settingsPersistence.savedSettings.count, 1)
    }

    func testCocoaCenterFlipsYAgainstPrimaryHeight() {
        let center = AppDelegate.cocoaCenter(
            cgBounds: ["X": 100, "Y": 200, "Width": 800, "Height": 600],
            primaryHeight: 1440
        )
        XCTAssertEqual(center?.x, 500)
        XCTAssertEqual(center?.y, 940)
    }

    func testCocoaCenterRejectsTinyWindows() {
        XCTAssertNil(AppDelegate.cocoaCenter(
            cgBounds: ["X": 0, "Y": 0, "Width": 100, "Height": 100],
            primaryHeight: 1440
        ))
        XCTAssertNil(AppDelegate.cocoaCenter(cgBounds: [:], primaryHeight: 1440))
    }

    private func makeDelegate(
        draftPersistence: RecordingDraftPersistence,
        settingsPersistence: RecordingSettingsPersistence
    ) -> AppDelegate {
        let delegate = AppDelegate()
        delegate.state = AppState(
            settings: RetypoSettings(),
            draftPersistence: draftPersistence,
            settingsPersistence: settingsPersistence
        )
        return delegate
    }
}
