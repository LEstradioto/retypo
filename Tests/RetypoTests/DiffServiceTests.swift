import XCTest
@testable import Retypo

final class DiffServiceTests: XCTestCase {
    func testIdenticalTextReturnsNoChanges() {
        XCTAssertEqual(DiffService.compactDiff(original: "hello", corrected: "hello"), "No changes")
    }

    func testDifferentTextReturnsBothLines() {
        let result = DiffService.compactDiff(original: "old", corrected: "new")
        XCTAssertEqual(result, "− old\n+ new")
    }

    func testEmptyOriginalAndCorrected() {
        XCTAssertEqual(DiffService.compactDiff(original: "", corrected: ""), "No changes")
    }

    func testEmptyOriginalNonEmptyCorrected() {
        XCTAssertEqual(DiffService.compactDiff(original: "", corrected: "x"), "− \n+ x")
    }
}
