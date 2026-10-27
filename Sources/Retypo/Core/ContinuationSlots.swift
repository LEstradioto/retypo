import Foundation

/// Main-actor once-only registry for checked continuations. Jobs resolve
/// exactly once — by the session, by a timeout, or by cleanup — so a stalled
/// engine can never leave a caller hanging. Used by AppleTranslationBridge;
/// extracted so the bookkeeping is testable without the Translation framework.
@MainActor
final class ContinuationSlots {
    private var slots: [UUID: CheckedContinuation<String, Error>] = [:]

    func register(_ id: UUID, _ continuation: CheckedContinuation<String, Error>) {
        slots[id] = continuation
    }

    /// First resolve wins; later resolves are no-ops.
    func resolve(_ id: UUID, with result: Result<String, Error>) {
        guard let continuation = slots.removeValue(forKey: id) else { return }
        continuation.resume(with: result)
    }

    func resolveAll(with result: Result<String, Error>) {
        for id in Array(slots.keys) {
            resolve(id, with: result)
        }
    }

    var pendingCount: Int { slots.count }
}
