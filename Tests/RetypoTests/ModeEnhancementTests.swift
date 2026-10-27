import XCTest
@testable import Retypo

@MainActor
final class ModeEnhancementTests: XCTestCase {
    /// Every modes.json written before enhanced modes must still load: a
    /// decoding failure would fall back to the defaults and drop the user's
    /// custom modes.
    func testModesSavedBeforeEnhancementStillDecode() throws {
        let legacy = #"[{"id":"mine","title":"Mine","instruction":"Do it","isEnabled":true}]"#
        let modes = try JSONDecoder().decode([EditAction].self, from: Data(legacy.utf8))
        XCTAssertNil(modes.first?.enhancement)
        XCTAssertEqual(modes.first?.isEnhanced, false)
    }

    func testEnhancementRoundTrips() throws {
        var mode = EditAction(id: "sac", title: "SAC", instruction: "Reply")
        mode.enhancement = ModeEnhancement(sources: [ReferenceSource(path: "/Users/me/kb", isFolder: true)], webSearch: true)
        let decoded = try JSONDecoder().decode(EditAction.self, from: JSONEncoder().encode(mode))
        XCTAssertEqual(decoded, mode)
    }

    func testPartialEnhancementJSONFillsDefaults() throws {
        let decoded = try JSONDecoder().decode(ModeEnhancement.self, from: Data(#"{"webSearch":true}"#.utf8))
        XCTAssertEqual(decoded, ModeEnhancement(isOn: true, sources: [], webSearch: true))
    }

    func testAModeResearchesOnlyWhenOnAndGivenSomethingToUse() {
        let docs = [ReferenceSource(path: "/kb", isFolder: true)]
        XCTAssertTrue(ModeEnhancement(sources: docs).isActive)
        XCTAssertTrue(ModeEnhancement(webSearch: true).isActive)
        XCTAssertFalse(ModeEnhancement().isActive)
        XCTAssertFalse(ModeEnhancement(isOn: false, sources: docs, webSearch: true).isActive)
    }

    // MARK: Editing from the mode editor

    /// `AppState` loads modes from the store, which under XCTest is a
    /// scratch folder shared by the whole run: start every test from defaults.
    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: AppFiles.url("modes.json"))
    }

    private func makeState() -> AppState {
        AppState(settings: RetypoSettings(), draftPersistence: RecordingDraftPersistence(), settingsPersistence: RecordingSettingsPersistence())
    }

    private func enhancement(_ state: AppState, _ id: String) -> ModeEnhancement? {
        state.actions.first { $0.id == id }?.enhancement
    }

    func testAttachingTwiceKeepsOneCopy() {
        let state = makeState()
        let url = URL(fileURLWithPath: "/tmp/notes.md")
        state.attachReferences([url], modeID: "improve")
        state.attachReferences([url], modeID: "improve")
        XCTAssertEqual(enhancement(state, "improve")?.sources.map(\.path), ["/tmp/notes.md"])
    }

    /// Switching off must not make the user pick every file again.
    func testSwitchingOffKeepsTheSources() {
        let state = makeState()
        state.attachReferences([URL(fileURLWithPath: "/tmp/notes.md")], modeID: "improve")
        state.setEnhanced(false, modeID: "improve")
        XCTAssertEqual(enhancement(state, "improve")?.isOn, false)
        XCTAssertEqual(enhancement(state, "improve")?.sources.count, 1)
        XCTAssertEqual(state.actions.first { $0.id == "improve" }?.isEnhanced, false)
    }

    func testDetachAndWebToggle() {
        let state = makeState()
        state.attachReferences([URL(fileURLWithPath: "/tmp/a.md")], modeID: "improve")
        let source = ReferenceSource(path: "/tmp/a.md", isFolder: false)
        state.detachReference(source, modeID: "improve")
        state.setWebSearch(true, modeID: "improve")
        XCTAssertEqual(enhancement(state, "improve"), ModeEnhancement(sources: [], webSearch: true))
    }

    func testCorrectCannotBeEnhanced() {
        let state = makeState()
        state.setWebSearch(true, modeID: "correct")
        XCTAssertNil(enhancement(state, "correct"))
    }
}
