import AppKit
import XCTest
@testable import Retypo

final class ReferencePlannerTests: XCTestCase {
    private var fixture: ReferenceFixture!

    override func setUpWithError() throws {
        fixture = try ReferenceFixture()
    }

    override func tearDown() {
        fixture.remove()
    }

    private func sources(_ paths: [String]) -> [ReferenceSource] {
        paths.map { ReferenceSource(url: fixture.url($0)) }
    }

    func testNoSourcesPlansNothing() {
        XCTAssertEqual(ReferencePlanner.plan(for: []), .none)
    }

    func testSmallSourcesAreSentWholeWithLabelledPaths() throws {
        try fixture.write("kb/a.md", "alpha")
        try fixture.write("kb/sub/b.txt", "beta")
        try fixture.write("glossary.md", "gamma")
        let plan = ReferencePlanner.plan(for: sources(["kb", "glossary.md"]))
        XCTAssertEqual(plan, .inline([
            ReferenceDocument(path: "kb/a.md", text: "alpha"),
            ReferenceDocument(path: "kb/sub/b.txt", text: "beta"),
            ReferenceDocument(path: "glossary.md", text: "gamma")
        ]))
    }

    func testSourcesOverTheBudgetAreSearchedOnDemand() throws {
        try fixture.write("vault/big.md", String(repeating: "x", count: ReferencePlanner.inlineCharacterBudget + 1))
        guard case .onDemand(let roots, let fileCount) = ReferencePlanner.plan(for: sources(["vault"])) else {
            return XCTFail("expected an on-demand plan")
        }
        XCTAssertEqual(roots.map(\.label), ["vault"])
        XCTAssertEqual(fileCount, 1)
    }

    func testManySmallFilesGoOnDemandWithoutReadingThem() throws {
        for index in 0...ReferencePlanner.inlineFileLimit { try fixture.write("notes/\(index).md", "n") }
        XCTAssertTrue(ReferencePlanner.plan(for: sources(["notes"])).needsTools)
    }

    func testFoldersWithTheSameNameGetDistinctLabels() throws {
        try fixture.write("a/docs/x.md", "x")
        try fixture.write("b/docs/y.md", "y")
        XCTAssertEqual(ReferenceCatalog.roots(for: sources(["a/docs", "b/docs"])).map(\.label), ["docs", "docs-2"])
    }

    // MARK: Text extraction

    func testWordDocumentsAreReadAsText() throws {
        let document = NSAttributedString(string: "Política de reembolso: 7 dias.")
        let data = try document.data(from: NSRange(location: 0, length: document.length),
                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
        let url = try fixture.writeData("policy.docx", data)
        XCTAssertEqual(ReferenceText.extract(from: url)?.trimmingCharacters(in: .whitespacesAndNewlines), "Política de reembolso: 7 dias.")
    }

    func testPDFTextIsExtracted() throws {
        let url = fixture.url("faq.pdf")
        try PDFFixture.write("Prazo de reembolso: sete dias", to: url)
        XCTAssertTrue(ReferenceText.extract(from: url)?.contains("Prazo de reembolso") == true)
    }

    func testLatin1TextFallsBackInsteadOfFailing() throws {
        let url = try fixture.writeData("legacy.txt", try XCTUnwrap("ação".data(using: .isoLatin1)))
        XCTAssertEqual(ReferenceText.extract(from: url), "ação")
    }

    func testBinaryContentIsNotText() throws {
        let url = try fixture.writeData("blob.dat", Data([0x41, 0x00, 0x42]))
        XCTAssertNil(ReferenceText.extract(from: url))
    }
}

/// Draws one line of real text into a PDF page, so PDFKit has something to extract.
enum PDFFixture {
    static func write(_ text: String, to url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: 400, height: 200)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw LLMError.invalidResponse }
        context.beginPDFPage(nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 14)]))
        context.textPosition = CGPoint(x: 20, y: 100)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
    }
}
