import XCTest
@testable import RetypoAir

/// Once-only continuation bookkeeping: a stalled engine must surface as an
/// error exactly once, never crash on double-resume, never hang the caller.
@MainActor
final class ContinuationSlotsTests: XCTestCase {
    func testResolveIsOnceOnly() async throws {
        let slots = ContinuationSlots()
        let id = UUID()
        let first = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            slots.register(id, continuation)
            slots.resolve(id, with: .success("one"))
            slots.resolve(id, with: .success("two"))
        }
        XCTAssertEqual(first, "one")
        XCTAssertEqual(slots.pendingCount, 0)
    }

    func testResolveAllFailsPending() async {
        let slots = ContinuationSlots()
        let id = UUID()
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                slots.register(id, continuation)
                slots.resolveAll(with: .failure(LiveTranslationError.appleTimedOut))
            }
            XCTFail("expected appleTimedOut")
        } catch {
            XCTAssertEqual(error as? LiveTranslationError, .appleTimedOut)
        }
        XCTAssertEqual(slots.pendingCount, 0)
    }

    func testResolvingUnknownIDIsNoop() {
        let slots = ContinuationSlots()
        slots.resolve(UUID(), with: .success("late"))
        XCTAssertEqual(slots.pendingCount, 0)
    }
}
