import AppKit
import SwiftUI
import XCTest
@testable import Retypo

/// Renders the README screenshots from the real views, so they can be redone
/// whenever the UI changes. `scripts/readme-shots.sh` runs this and turns the
/// PNGs into docs/images. Skipped unless RETYPO_README_SHOTS names a folder:
///
///     RETYPO_README_SHOTS=/tmp/shots swift test --filter ReadmeShotsTests
@MainActor
final class ReadmeShotsTests: XCTestCase {
    private typealias Fixtures = ReadmeShotFixtures

    func testRenderReadmeShots() throws {
        guard let path = ProcessInfo.processInfo.environment["RETYPO_README_SHOTS"] else {
            throw XCTSkip("Set RETYPO_README_SHOTS to an output folder to render the README images")
        }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (theme, name) in [(MainTheme.glass, "light"), (.dark, "dark")] {
            let shots = folder.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
            try renderRun(theme: theme, into: shots)
            try renderModes(theme: theme, into: shots)
            try renderCandidates(theme: theme, into: shots)
        }
    }

    /// The hero: the draft, the marks after "Improve Writing", the review.
    private func renderRun(theme: MainTheme, into folder: URL) throws {
        let draft = panel(theme: theme)
        draft.inputText = Fixtures.draft
        draft.wordsPerMinute = 104
        try render(RetypoView(), state: draft, size: NSSize(width: 760, height: 248), to: folder.appendingPathComponent("1-draft.png"))
        let state = afterARun(theme: theme)
        try render(RetypoView(), state: state, size: NSSize(width: 760, height: 248), to: folder.appendingPathComponent("2-marks.png"))
        state.toggleChangeReview()
        try render(RetypoView(), state: state, size: NSSize(width: 760, height: 248), to: folder.appendingPathComponent("3-review.png"))
    }

    /// The Cmd+D picker with an enhanced mode, and that mode's editor.
    private func renderModes(theme: MainTheme, into folder: URL) throws {
        let state = panel(theme: theme)
        // Inside the output folder, so the script's cleanup takes it too.
        let docsMode = try Fixtures.docsMode(in: folder.appendingPathComponent("fixture-docs", isDirectory: true))
        state.actions.insert(docsMode, at: 3)
        state.inputText = Fixtures.request
        state.toggleModePicker()
        try render(RetypoView(), state: state, size: NSSize(width: 760, height: 236), to: folder.appendingPathComponent("modes.png"))
        let editor = LauncherModeEditor(action: docsMode) {}
            .padding(14)
            .frame(width: 560)
            .background(Palette.window)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        try render(editor, state: state, size: nil, to: folder.appendingPathComponent("enhanced.png"), settle: 1)
    }

    /// Cmd+Shift+Enter: every enabled mode ran, one card each.
    private func renderCandidates(theme: MainTheme, into folder: URL) throws {
        let state = panel(theme: theme)
        state.inputText = Fixtures.request
        state.candidateResults = Fixtures.candidates.map { modeID, output in
            CandidateResult(
                action: EditAction.defaults.first { $0.id == modeID } ?? EditAction.defaults[0],
                output: output, diff: "", changes: TextDiff(original: Fixtures.request, revised: output),
                usage: TokenUsage(inputTokens: 380, outputTokens: 42, webSearches: nil), costUSD: 0.0002
            )
        }
        state.selectedCandidateIndex = 1
        // Wide enough for all three cards.
        try render(CandidateOverlayWindowView(), state: state, size: NSSize(width: 830, height: 250), to: folder.appendingPathComponent("candidates.png"))
    }

    /// The panel right after "Improve Writing" ran on the draft.
    private func afterARun(theme: MainTheme) -> AppState {
        let state = panel(theme: theme)
        state.inputText = Fixtures.draft
        let improve = EditAction.defaults.first { $0.id == "improve" } ?? EditAction.defaults[0]
        state.applyResult(AppState.ActionOutcome(
            text: Fixtures.revised, original: Fixtures.draft, changed: true,
            response: LLMResponse(text: Fixtures.revised), action: improve, instruction: ""
        ))
        state.cost.lastCost = CostSnapshot(usage: TokenUsage(inputTokens: 412, outputTokens: 96, webSearches: nil), costUSD: 0.0004)
        state.wordsPerMinute = 104
        return state
    }

    private func panel(theme: MainTheme) -> AppState {
        var settings = RetypoSettings()
        settings.autoCopy = false
        settings.mainTheme = theme
        settings.currentActionID = "improve"
        Palette.current = theme
        let state = AppState(settings: settings, draftPersistence: RecordingDraftPersistence(), settingsPersistence: RecordingSettingsPersistence())
        state.host = MockPanelHost()
        state.setSelectedModel("claude-haiku-5-5", provider: .anthropic)
        return state
    }

    /// Lays the view out in an offscreen window with the theme's appearance;
    /// `size` nil means the view's own fitting size.
    private func render<V: View>(_ view: V, state: AppState, size: NSSize?, to url: URL, settle: TimeInterval = 0.3) throws {
        let hosting = NSHostingView(rootView: view.environmentObject(state))
        hosting.frame = NSRect(origin: .zero, size: size ?? hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = state.settings.mainTheme.nsAppearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        try png(of: hosting).write(to: url)
    }

    /// At 2x, whatever screen the test runs on.
    private func png(of view: NSView) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width) * 2, pixelsHigh: Int(view.bounds.height) * 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }
}

