import XCTest
@testable import RetypoAir

@MainActor
final class DebouncerTests: XCTestCase {
    func testCancelPreventsScheduledOperation() async throws {
        let debouncer = Debouncer()
        var executionCount = 0
        debouncer.schedule(milliseconds: 10) {
            executionCount += 1
        }

        debouncer.cancel()
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(executionCount, 0)
    }
}
