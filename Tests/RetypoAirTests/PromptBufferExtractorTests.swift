import XCTest
@testable import RetypoAir

final class PromptBufferExtractorTests: XCTestCase {
    private let extractor = PromptBufferExtractor()

    func testExtractsClaudePromptBetweenDividerLines() {
        let buffer = """
        assistant output
        ╭────────────────────────────╮
        │ > fix the import flow      │
        │   keep code blocks intact  │
        ╰────────────────────────────╯
        ? for shortcuts
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .claudeDividerComposer)
        XCTAssertEqual(prompt?.text, "fix the import flow\nkeep code blocks intact")
    }

    func testExtractsBottomMarkedCodexPrompt() {
        let buffer = """
        previous answer

        › improve this parser
          preserve symbols like Map<String, Int>
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .accessibilityTextBuffer)
        XCTAssertEqual(prompt?.text, "improve this parser\npreserve symbols like Map<String, Int>")
    }

    func testBottomMarkedCodexPromptPreservesInternalBlankLines() {
        let buffer = """
        previous answer

        › testando nova,ente

          legal


          123


        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.text, "testando nova,ente\n\nlegal\n\n\n123")
    }

    func testTmuxSplitPaneTextIsTrimmedFromMultilinePrompt() {
        let boundary = String(repeating: " ", count: 43)
        let buffer = [
            "previous answer",
            "› testando nova,ente\(String(repeating: " ", count: 22))re-typoer on main via swift",
            "\(boundary)scripts/dev-app.sh",
            "  legal\(String(repeating: " ", count: 36))[1/1] Planning build",
            "\(boundary)Building for debugging...",
            "\(boundary)[73/73] Applying RetypoAir",
            "  123\(String(repeating: " ", count: 38))Build complete! (2.48s)",
            "\(boundary)Built: /Users/lestra/dev/re-typoer/build-dev/RetypoAir-dev.app"
        ].joined(separator: "\n")

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.text, "testando nova,ente\n\nlegal\n\n\n123")
    }

    func testCodexPromptStopsBeforeModelAndWorkspaceStatusLines() {
        let buffer = """
        previous answer

        › ok interessante hein
          vamos testar
        gpt-5.5 xhigh fast · ~/dev/re-typoer · Context 62% used · 258K window · Goal achieved (4m)
        workspace-1 1:erp-004 2:contra 3:re-typoer 9s Alt+M = menu 23:12 07-May
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.text, "ok interessante hein\nvamos testar")
    }

    func testCodexPromptDoesNotIncludeOutputAboveMarkerInAnotherPane() {
        let buffer = """
        Built: /Users/lestra/dev/re-typoer/build-dev/RetypoAir-dev.app Open it, then grant Accessibility permission
        › será que precisamos desse fallback visual?
          ou soh o semantic ali resolve?
        re-typoer on  master [!?] via 🐦 v6.2.1 took 5s
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.text, "será que precisamos desse fallback visual?\nou soh o semantic ali resolve?")
    }

    func testExtractsClaudePromptBetweenPlainDividerLines() {
        let buffer = """
        previous answer
        ─────────────────────────────────────────────────────────────
        ❯ vamos testar o claude agora
          testando
          test
        ─────────────────────────────────────────────────────────────
          ⏵⏵ auto mode on · 1 shell
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .claudeDividerComposer)
        XCTAssertEqual(prompt?.text, "vamos testar o claude agora\ntestando\ntest")
    }

    func testClaudeDividerPromptTrimsTmuxSplitPaneText() {
        let boundary = String(repeating: " ", count: 43)
        let buffer = [
            "previous answer",
            "─────────────────────────────────────────────────────────────",
            "❯ testando nova,ente\(String(repeating: " ", count: 23))re-typoer on main via swift",
            "\(boundary)scripts/dev-app.sh",
            "  legal\(String(repeating: " ", count: 36))[1/1] Planning build",
            "\(boundary)Building for debugging...",
            "\(boundary)[73/73] Applying RetypoAir",
            "  123\(String(repeating: " ", count: 38))Build complete! (2.48s)",
            "─────────────────────────────────────────────────────────────"
        ].joined(separator: "\n")

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.text, "testando nova,ente\n\nlegal\n\n\n123")
    }

    func testIgnoresSidebarDividerWithoutPromptMarkerAndFallsBackToArrow() {
        let buffer = """
        ┌─ Sessions ──────┐
        │ session 1       │
        │ session 2       │
        ├─────────────────┤
        │ files           │
        │ actions         │
        └─────────────────┘
        re-typoer on  master via 🐦 v6.2.1
        ❯ build the parser fix
          keep the arrow heuristic
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .accessibilityTextBuffer)
        XCTAssertEqual(prompt?.text, "build the parser fix\nkeep the arrow heuristic")
    }

    func testExtractsClaudeComposerFromTmuxMiddlePaneWithSidebar() {
        let middlePad = String(repeating: "─", count: 192)
        let bottomMid = String(repeating: "─", count: 192)
        let promptPad = String(repeating: " ", count: 100)
        let buffer = [
            "                                    │\(middlePad)│",
            " ───────────────────────────────────│❯ testando 12\(promptPad)│",
            " ⇥ cycle  ⏎ go  → agents  f filter  │\(bottomMid)│"
        ].joined(separator: "\n")

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .claudeDividerComposer)
        XCTAssertEqual(prompt?.text, "testando 12")
    }

    func testExtractsMultilineClaudeComposerFromTmuxMiddlePane() {
        let topBorder = String(repeating: "─", count: 80)
        let bottomBorder = String(repeating: "─", count: 80)
        let pad = String(repeating: " ", count: 40)
        let buffer = [
            "                          │\(topBorder)│",
            " ─────────────────────────│❯ first line of prompt\(pad)│",
            "  ⇥ cycle  ⏎ go           │  second line\(String(repeating: " ", count: 50))│",
            "                          │\(bottomBorder)│"
        ].joined(separator: "\n")

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .claudeDividerComposer)
        XCTAssertEqual(prompt?.text, "first line of prompt\nsecond line")
    }

    func testExtractsVSCodeClaudeAccessibleViewBottomComposer() {
        let nbsp = "\u{00A0}"
        let divider = String(repeating: "─", count: 152)
        let buffer = """
        previous assistant message
          ✔ S6.4a hardening
          ✔ S6.4b — Grant tokens

        \(divider)
        ❯\(nbsp)tste
        \(divider)
          ⏵⏵ auto mode on · 2 shells
        """

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .claudeDividerComposer)
        XCTAssertEqual(prompt?.text, "tste")
    }

    func testExtractsCodexPromptFromTmuxMiddlePaneWithoutClosingDivider() {
        let pad = String(repeating: " ", count: 100)
        let buffer = [
            "                                    │─ Worked for 23m 09s ─────────────────────────│",
            "                                    │\(pad)│",
            " ───────────────────────────────────│                                    \(pad)│",
            " ⇥ cycle  ⏎ go  → agents  f filter  │› testes fsdafsad fssfadsfad\(pad)│",
            " d hide  x kill                     │\(pad)│",
            "                                    │  gpt-5.5 high fast · Context 86% used · 258K window\(pad)│"
        ].joined(separator: "\n")

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .accessibilityTextBuffer)
        XCTAssertEqual(prompt?.text, "testes fsdafsad fssfadsfad")
    }

    func testExtractsClaudeComposerWithNonBreakingSpaceAfterArrow() {
        let nbsp = "\u{00A0}"
        let topBorder = String(repeating: "─", count: 192)
        let bottomBorder = String(repeating: "─", count: 192)
        let pad = String(repeating: " ", count: 100)
        let buffer = [
            "                                    │\(topBorder)│",
            " ───────────────────────────────────│❯\(nbsp)teste\(pad)│",
            " ⇥ cycle  ⏎ go  → agents  f filter  │\(bottomBorder)│"
        ].joined(separator: "\n")

        let prompt = extractor.prompt(from: buffer)

        XCTAssertEqual(prompt?.kind, .claudeDividerComposer)
        XCTAssertEqual(prompt?.text, "teste")
    }

    func testIgnoresTranscriptWithoutPromptSemantics() {
        let buffer = """
        previous answer
        this is just terminal output
        """

        XCTAssertNil(extractor.prompt(from: buffer))
    }
}
