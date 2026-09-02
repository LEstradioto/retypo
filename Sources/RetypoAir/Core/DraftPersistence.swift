import Foundation

protocol DraftPersisting: AnyObject {
    func load() -> String
    func save(_ text: String)
    func flush()
}

/// Plain-text draft (not JSON, kept separate from the `PersistedFile<T>` family).
enum DraftStore {
    static var fileURL: URL { AppFiles.url("draft.txt") }

    static func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    static func save(_ text: String) {
        do {
            try FileManager.default.createDirectory(at: AppFiles.directory, withIntermediateDirectories: true)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            fputs("RetypoAir draft save failed: \(error)\n", stderr)
        }
    }
}

final class CoalescingDraftPersistence: DraftPersisting {
    typealias LoadOperation = () -> String
    typealias SaveOperation = (String) -> Void

    private let queue = DispatchQueue(label: "air.retypo.draft-persistence", qos: .utility)
    private let pendingTextLock = NSLock()
    private let loadOperation: LoadOperation
    private let saveOperation: SaveOperation
    private var pendingText: String?
    private var drainScheduled = false

    init(
        loadOperation: @escaping LoadOperation = DraftStore.load,
        saveOperation: @escaping SaveOperation = DraftStore.save
    ) {
        self.loadOperation = loadOperation
        self.saveOperation = saveOperation
    }

    func load() -> String {
        queue.sync(execute: loadOperation)
    }

    func save(_ text: String) {
        guard replacePendingText(with: text) else { return }
        queue.async { [self] in
            drainPendingWrites()
        }
    }

    func flush() {
        // Normal termination waits for the last coalesced value so async saves
        // do not trade UI responsiveness for a missing final draft.
        queue.sync {}
    }

    private func replacePendingText(with text: String) -> Bool {
        pendingTextLock.lock()
        defer { pendingTextLock.unlock() }
        pendingText = text
        guard !drainScheduled else { return false }
        drainScheduled = true
        return true
    }

    private func drainPendingWrites() {
        while let text = takePendingText() {
            saveOperation(text)
        }
    }

    private func takePendingText() -> String? {
        pendingTextLock.lock()
        defer { pendingTextLock.unlock() }
        guard let pendingText else {
            drainScheduled = false
            return nil
        }
        self.pendingText = nil
        return pendingText
    }
}
