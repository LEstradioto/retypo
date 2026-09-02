import AppKit
import XCTest
@testable import RetypoAir

@MainActor
final class AppDelegateLifecycleTests: XCTestCase {
    func testTerminationFlushesPendingDraftWrites() {
        let draftPersistence = RecordingDraftPersistence()
        let delegate = makeDelegate(draftPersistence: draftPersistence)

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertEqual(draftPersistence.flushCount, 1)
    }

    func testHidingPanelFlushesPendingDraftWrites() {
        let draftPersistence = RecordingDraftPersistence()
        let delegate = makeDelegate(draftPersistence: draftPersistence)

        delegate.hidePanelAndFocusPrevious()

        XCTAssertEqual(draftPersistence.flushCount, 1)
    }

    private func makeDelegate(draftPersistence: RecordingDraftPersistence) -> AppDelegate {
        let delegate = AppDelegate()
        delegate.state = AppState(
            settings: RetypoSettings(),
            draftPersistence: draftPersistence
        )
        return delegate
    }
}
