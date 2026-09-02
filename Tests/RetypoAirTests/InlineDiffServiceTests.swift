import XCTest
@testable import RetypoAir

final class InlineDiffServiceTests: XCTestCase {
    func testIdenticalTextHasNoChanges() {
        let ranges = InlineDiffService.changedRanges(original: "hello world", corrected: "hello world")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testEmptyCorrectedReturnsNoChanges() {
        let ranges = InlineDiffService.changedRanges(original: "anything", corrected: "")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testSingleWordReplacementMarksOnlyChangedToken() {
        let count = InlineDiffService.changedWordCount(original: "the cat sat", corrected: "the dog sat")
        XCTAssertEqual(count, 1)
    }

    func testInsertedWordCountedAsChange() {
        let count = InlineDiffService.changedWordCount(original: "the sat", corrected: "the cat sat")
        XCTAssertEqual(count, 1)
    }

    func testFullReplacementMergesAdjacentChanges() {
        // mergeNearby collapses changes ≤ 2 chars apart into one range.
        let count = InlineDiffService.changedWordCount(original: "alpha", corrected: "bravo charlie")
        XCTAssertEqual(count, 1)
    }

    func testDistantChangesStayAsTwoRanges() {
        let count = InlineDiffService.changedWordCount(
            original: "the cat sat on the mat",
            corrected: "the dog sat on the rug"
        )
        XCTAssertEqual(count, 2)
    }

    func testRangesProduceValidNSRanges() {
        let ranges = InlineDiffService.changedRanges(
            original: "alpha bravo charlie",
            corrected: "alpha BRAVO charlie"
        )
        let nsString = "alpha BRAVO charlie" as NSString
        for range in ranges {
            XCTAssertGreaterThanOrEqual(range.location, 0)
            XCTAssertLessThanOrEqual(NSMaxRange(range), nsString.length)
        }
    }

    func testTrailingPunctuationIgnored() {
        let count = InlineDiffService.changedWordCount(
            original: "hello world",
            corrected: "hello world!"
        )
        XCTAssertEqual(count, 0)
    }

    func testExactLCSStaysInsideFixedCellBudget() {
        XCTAssertTrue(InlineDiffService.shouldUseExactLCS(oldTokenCount: 1_000, newTokenCount: 1_000))
        XCTAssertFalse(InlineDiffService.shouldUseExactLCS(oldTokenCount: 1_001, newTokenCount: 1_001))
        XCTAssertFalse(InlineDiffService.shouldUseExactLCS(oldTokenCount: 10_000, newTokenCount: 10_000))
    }

    func testLargeSingleReplacementKeepsPreciseRange() throws {
        let original = Array(repeating: "alpha", count: 10_000).joined(separator: " ")
        var correctedWords = Array(repeating: "alpha", count: 10_000)
        correctedWords[5_000] = "bravo"
        let corrected = correctedWords.joined(separator: " ")

        let ranges = InlineDiffService.changedRanges(original: original, corrected: corrected)

        XCTAssertEqual(ranges.count, 1)
        let changedRange = try XCTUnwrap(ranges.first)
        XCTAssertEqual((corrected as NSString).substring(with: changedRange), "bravo")
    }

    func testLargeFullRewriteReturnsOneBoundedRange() {
        let original = Array(repeating: "alpha", count: 2_000).joined(separator: " ")
        let corrected = Array(repeating: "bravo", count: 2_000).joined(separator: " ")

        let ranges = InlineDiffService.changedRanges(original: original, corrected: corrected)

        XCTAssertEqual(ranges, [NSRange(location: 0, length: (corrected as NSString).length)])
    }
}
