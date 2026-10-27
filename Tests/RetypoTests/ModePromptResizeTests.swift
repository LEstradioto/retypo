import AppKit
import XCTest
@testable import Retypo

@MainActor
final class ModePromptResizeTests: XCTestCase {
    private let range: ClosedRange<CGFloat> = 64...640
    private let origin = TextareaResize.Origin(height: 140, mouseY: 500)

    func testDraggingDownGrowsTheTextarea() {
        XCTAssertEqual(TextareaResize.height(from: origin, mouseY: 420, range: range), 220)
    }

    func testDraggingUpShrinksTheTextarea() {
        XCTAssertEqual(TextareaResize.height(from: origin, mouseY: 540, range: range), 100)
    }

    func testDragStopsAtTheLimits() {
        XCTAssertEqual(TextareaResize.height(from: origin, mouseY: 900, range: range), 64)
        XCTAssertEqual(TextareaResize.height(from: origin, mouseY: -900, range: range), 640)
    }

    func testCommittedHeightIsClampedAndPersisted() {
        let persistence = RecordingSettingsPersistence()
        let state = AppState(settings: RetypoSettings(), draftPersistence: RecordingDraftPersistence(), settingsPersistence: persistence)
        state.setModePromptHeight(5_000)
        XCTAssertEqual(state.settings.modePromptHeight, 640)
        XCTAssertEqual(persistence.savedSettings.last?.modePromptHeight, 640)
    }

    func testSettingsWithoutPromptHeightDecodeToTheDefault() throws {
        let settings = try JSONDecoder().decode(RetypoSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(settings.modePromptHeight, 140)
    }

    func testPromptHeightSurvivesARoundTrip() throws {
        var settings = RetypoSettings()
        settings.modePromptHeight = 333
        let decoded = try JSONDecoder().decode(RetypoSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.modePromptHeight, 333)
    }

    // MARK: Panel placement after content growth

    private let visible = NSRect(x: 0, y: 0, width: 1_000, height: 800)

    /// AppKit grows the window downward from its top edge; a panel docked
    /// at the bottom moves back up, so it ends up growing upward.
    func testPanelPushedBelowTheScreenMovesBackUp() {
        let grown = NSRect(x: 10, y: -150, width: 400, height: 500)
        XCTAssertEqual(PanelPlacement.onScreen(grown, visible: visible), NSRect(x: 10, y: 0, width: 400, height: 500))
    }

    func testPanelThatFitsStaysPut() {
        XCTAssertNil(PanelPlacement.onScreen(NSRect(x: 10, y: 34, width: 400, height: 500), visible: visible))
    }

    func testPanelTallerThanTheScreenKeepsItsTopVisible() {
        let tall = NSRect(x: 10, y: -400, width: 400, height: 1_000)
        XCTAssertEqual(PanelPlacement.onScreen(tall, visible: visible)?.maxY, visible.maxY)
    }
}
