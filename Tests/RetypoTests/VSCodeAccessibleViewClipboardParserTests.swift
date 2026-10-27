import XCTest
@testable import Retypo

final class VSCodeAccessibleViewClipboardParserTests: XCTestCase {
    private let parser = VSCodeAccessibleViewClipboardParser()
    private let marker = "__RETYP_AIR_TEST_MARKER__"

    func testRejectsUnchangedMarkerClipboard() {
        let prompt = parser.prompt(from: marker, marker: marker)

        XCTAssertNil(prompt)
    }

    func testExtractsSingleLineSemanticPrompt() {
        let prompt = parser.prompt(from: "› fix vscode import", marker: marker)

        XCTAssertEqual(prompt?.text, "fix vscode import")
        XCTAssertEqual(prompt?.kind, .accessibilityTextBuffer)
    }

    func testRejectsSingleLineWindowTitleFallback() {
        let text = "AppDelegate.swift - re-typoer - Visual Studio Code"

        let prompt = parser.prompt(from: text, marker: marker)

        XCTAssertNil(prompt)
    }

    func testAllowsMultilineVisibleBottomFallback() {
        let text = """
        draft first line
        draft second line
        """

        let prompt = parser.prompt(from: text, marker: marker)

        XCTAssertEqual(prompt?.text, "draft first line\ndraft second line")
    }
}
