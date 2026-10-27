import XCTest
@testable import Retypo

final class ReferenceToolboxTests: XCTestCase {
    private var fixture: ReferenceFixture!

    override func setUpWithError() throws {
        fixture = try ReferenceFixture()
        try fixture.write("docs/faq/reembolso.md", "# Reembolso\nO reembolso é feito em até 7 dias úteis.\nDúvidas: suporte.")
        try fixture.write("docs/guia.txt", "Atenção: a glosa é a recusa de pagamento pelo convênio.")
        try fixture.write("docs/node_modules/lib/readme.md", "reembolso dependency noise")
        try fixture.write("docs/.hidden.md", "reembolso hidden")
        try fixture.writeData("docs/logo.png", Data([0x89, 0x50, 0x4E, 0x47]))
        try fixture.write("outside/secret.txt", "senha: 1234")
    }

    override func tearDown() {
        fixture.remove()
    }

    private func toolbox() -> ReferenceToolbox {
        ReferenceToolbox(roots: fixture.roots(["docs"]))
    }

    private func call(_ name: String, _ arguments: [String: Any]) -> ToolOutcome {
        toolbox().run(ToolCall(id: "call-1", name: name, arguments: arguments))
    }

    func testListsReadableFilesAndSkipsDependenciesHiddenAndBinaries() {
        let outcome = call("list_files", [:])
        XCTAssertFalse(outcome.isError)
        XCTAssertEqual(outcome.content.split(separator: "\n").map { $0.split(separator: " ").first.map(String.init) ?? "" },
                       ["docs/faq/reembolso.md", "docs/guia.txt"])
    }

    func testListFiltersByPatternAndFolder() {
        XCTAssertEqual(call("list_files", ["pattern": "*.TXT"]).content.hasPrefix("docs/guia.txt"), true)
        XCTAssertFalse(call("list_files", ["path": "docs/faq"]).content.contains("guia.txt"))
    }

    /// "reembolso" must find "Reembolso" and "atencao" must find "Atenção".
    func testSearchIgnoresCaseAndAccentsAndTakesAlternatives() {
        let outcome = call("search_files", ["query": "REEMBOLSO|atencao"])
        XCTAssertFalse(outcome.isError)
        XCTAssertTrue(outcome.content.contains("docs/faq/reembolso.md:1: # Reembolso"))
        XCTAssertTrue(outcome.content.contains("docs/faq/reembolso.md:2: O reembolso"))
        XCTAssertTrue(outcome.content.contains("docs/guia.txt:1: Atenção"))
        XCTAssertFalse(outcome.content.contains("node_modules"))
    }

    func testSearchWithoutMatchesSaysSo() {
        XCTAssertTrue(call("search_files", ["query": "inexistente"]).content.hasPrefix("No lines match"))
    }

    func testReadReturnsNumberedLinesAndPointsToTheRest() throws {
        let outcome = try XCTUnwrap(Optional(call("read_file", ["path": "docs/faq/reembolso.md", "start_line": 2, "end_line": 2])))
        XCTAssertEqual(outcome.content, """
        docs/faq/reembolso.md (lines 2-2 of 3)
        2: O reembolso é feito em até 7 dias úteis.
        More below: call read_file with start_line 3.
        """)
    }

    func testReadAcceptsTheAbsolutePathOfAnAttachedFile() {
        let outcome = call("read_file", ["path": fixture.url("docs/guia.txt").path])
        XCTAssertFalse(outcome.isError)
        XCTAssertTrue(outcome.content.contains("1: Atenção"))
    }

    // MARK: Confinement — the model must not reach files the user did not attach.

    func testParentTraversalIsRefused() {
        let outcome = call("read_file", ["path": "docs/../outside/secret.txt"])
        XCTAssertTrue(outcome.isError)
        XCTAssertTrue(outcome.content.contains("outside the attached sources"))
    }

    func testAbsolutePathOutsideTheSourcesIsRefused() {
        let outcome = call("read_file", ["path": fixture.url("outside/secret.txt").path])
        XCTAssertTrue(outcome.isError)
        XCTAssertFalse(outcome.content.contains("1234"))
    }

    func testSymlinkPointingOutsideIsRefused() throws {
        try FileManager.default.createSymbolicLink(at: fixture.url("docs/link.txt"), withDestinationURL: fixture.url("outside/secret.txt"))
        let outcome = call("read_file", ["path": "docs/link.txt"])
        XCTAssertTrue(outcome.isError)
        XCTAssertFalse(outcome.content.contains("1234"))
    }

    /// Attaching one file does not open its folder.
    func testAFileRootDoesNotExposeItsSiblings() {
        let toolbox = ReferenceToolbox(roots: fixture.roots(["docs/guia.txt"]))
        XCTAssertFalse(toolbox.run(ToolCall(id: "1", name: "read_file", arguments: ["path": "guia.txt"])).isError)
        let sibling = toolbox.run(ToolCall(id: "2", name: "read_file", arguments: ["path": fixture.url("docs/faq/reembolso.md").path]))
        XCTAssertTrue(sibling.isError)
    }

    // MARK: Errors the model can act on

    func testUnknownToolAndMissingArgumentsComeBackAsErrors() {
        XCTAssertTrue(call("write_file", [:]).content.contains("Unknown tool \"write_file\""))
        XCTAssertTrue(call("search_files", ["query": "  "]).content.contains("needs a non-empty \"query\""))
        XCTAssertTrue(call("read_file", ["path": "docs/faq"]).content.contains("is a folder"))
        XCTAssertTrue(call("read_file", ["path": "docs/nope.md"]).content.contains("does not exist"))
    }

    func testOutcomeKeepsTheCallID() {
        XCTAssertEqual(call("list_files", [:]).callID, "call-1")
    }
}
