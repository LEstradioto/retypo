import AppKit
import XCTest
@testable import Retypo

@MainActor
final class ThemeSettingsTests: XCTestCase {
    private func makeState() -> (AppState, MockPanelHost) {
        let state = AppState(
            settings: RetypoSettings(),
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: RecordingSettingsPersistence()
        )
        let host = MockPanelHost()
        state.host = host
        return (state, host)
    }

    func testHexParsesSixDigitsWithOrWithoutHash() {
        XCTAssertNotNil(FontColorHex.color(from: "#FF0000"))
        XCTAssertNotNil(FontColorHex.color(from: "00FF00"))
        XCTAssertNil(FontColorHex.color(from: nil))
        XCTAssertNil(FontColorHex.color(from: "red"))
        XCTAssertNil(FontColorHex.color(from: "#FFF"))
    }

    func testPresetThemesHaveDefinitionsAndDarkAppearance() {
        for theme: MainTheme in [.monokai, .tokyoNight, .catppuccin] {
            XCTAssertNotNil(theme.definition, theme.rawValue)
            XCTAssertEqual(theme.nsAppearance?.name, NSAppearance.Name.darkAqua, theme.rawValue)
        }
        XCTAssertNil(MainTheme.glass.definition)
        XCTAssertNil(MainTheme.system.definition)
        XCTAssertNil(MainTheme.system.nsAppearance)
    }

    func testSetThemeSwitchesPaletteAndPushesAppearance() {
        let (state, host) = makeState()
        state.setTheme(.tokyoNight)
        XCTAssertEqual(Palette.current, .tokyoNight)
        XCTAssertEqual(host.appearanceHistory.first??.name, NSAppearance.Name.darkAqua)
        state.setTheme(.glass)
        XCTAssertEqual(Palette.current, .glass)
    }

    func testWindowOpacityClampsAndForwards() {
        let (state, host) = makeState()
        state.setWindowOpacity(0.1)
        XCTAssertEqual(state.settings.windowOpacity, 0.5)
        state.setWindowOpacity(2.0)
        XCTAssertEqual(state.settings.windowOpacity, 1.0)
        XCTAssertEqual(host.windowOpacityHistory, [0.5, 1.0])
    }

    func testEditorFontColorFollowsHexOrSystem() {
        let (state, _) = makeState()
        XCTAssertEqual(state.editorFontColor, .labelColor)
        state.setFontColorHex("#FF0000")
        XCTAssertEqual(Double(state.editorFontColor.usingColorSpace(.sRGB)?.redComponent ?? 0), 1.0, accuracy: 0.01)
    }
}
