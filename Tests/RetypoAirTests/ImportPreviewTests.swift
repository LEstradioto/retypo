import XCTest
@testable import RetypoAir

final class ImportPreviewTests: XCTestCase {
    func testFirstVisibleLineSkipsBlankLinesAndTrimsWhitespace() {
        let preview = ImportPreview.truncatedFirstVisibleLine("\n  First clipboard line  \nSecond line")

        XCTAssertEqual(preview, "First clipboard line")
    }

    func testFirstVisibleLineIsEmptyForWhitespaceOnlyText() {
        XCTAssertEqual(ImportPreview.truncatedFirstVisibleLine(" \n\t"), "")
    }

    func testFirstVisibleLineUsesEllipsisAtCharacterLimit() {
        let preview = ImportPreview.truncatedFirstVisibleLine("123456789", limit: 6)

        XCTAssertEqual(preview, "12345…")
    }
}
