import Foundation
import XCTest
@testable import RetypoAir

private final class LockedDraftBackend {
    private let lock = NSLock()
    private var storedText: String
    private var writes: [String] = []
    private var writeWasOnMainThread = false

    init(storedText: String) {
        self.storedText = storedText
    }

    func load() -> String {
        lock.lock()
        defer { lock.unlock() }
        return storedText
    }

    func save(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        storedText = text
        writes.append(text)
        writeWasOnMainThread = Thread.isMainThread
    }

    func snapshot() -> (writes: [String], writeWasOnMainThread: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (writes, writeWasOnMainThread)
    }
}

private final class PausingDraftBackend {
    let firstWriteStarted = XCTestExpectation(description: "first draft write started")
    private let releaseFirstWrite = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var writes: [String] = []

    func load() -> String {
        ""
    }

    func save(_ text: String) {
        lock.lock()
        writes.append(text)
        let shouldPause = writes.count == 1
        lock.unlock()
        guard shouldPause else { return }
        firstWriteStarted.fulfill()
        releaseFirstWrite.wait()
    }

    func resumeFirstWrite() {
        releaseFirstWrite.signal()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }
}

@MainActor
final class DraftPersistenceTests: XCTestCase {
    func testLoadUsesInjectedBackend() {
        let backend = LockedDraftBackend(storedText: "Recovered draft")
        let persistence = makePersistence(backend)

        XCTAssertEqual(persistence.load(), "Recovered draft")
    }

    func testSaveRunsOffMainThreadAndFlushWaitsForCompletion() {
        let backend = LockedDraftBackend(storedText: "")
        let persistence = makePersistence(backend)

        persistence.save("Latest draft")
        persistence.flush()

        let snapshot = backend.snapshot()
        XCTAssertEqual(snapshot.writes, ["Latest draft"])
        XCTAssertFalse(snapshot.writeWasOnMainThread)
    }

    func testBurstCoalescesToLatestPendingDraft() {
        let backend = PausingDraftBackend()
        let persistence = CoalescingDraftPersistence(
            loadOperation: backend.load,
            saveOperation: backend.save
        )

        persistence.save("first")
        wait(for: [backend.firstWriteStarted], timeout: 1)
        persistence.save("second")
        persistence.save("third")
        backend.resumeFirstWrite()
        persistence.flush()

        XCTAssertEqual(backend.snapshot(), ["first", "third"])
    }

    private func makePersistence(_ backend: LockedDraftBackend) -> CoalescingDraftPersistence {
        CoalescingDraftPersistence(
            loadOperation: backend.load,
            saveOperation: backend.save
        )
    }
}
