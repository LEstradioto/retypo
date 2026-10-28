import XCTest
@testable import Retypo

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

    /// Covers the path that runs the operation on purpose: it used to be
    /// covered only when debounces left by other tests fired before the
    /// process exited, so the pre-push coverage gate flaked.
    func testRescheduleRunsOnlyTheLatestOperation() async {
        let debouncer = Debouncer()
        var runs: [String] = []
        let latestRan = expectation(description: "latest operation ran")
        debouncer.schedule(milliseconds: 1) { runs.append("first") }
        debouncer.schedule(milliseconds: 1) {
            runs.append("second")
            latestRan.fulfill()
        }
        await fulfillment(of: [latestRan], timeout: 5)
        XCTAssertEqual(runs, ["second"])
    }
}
