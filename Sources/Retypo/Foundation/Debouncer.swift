import Foundation

final class Debouncer {
    private var task: Task<Void, Never>?

    func schedule(milliseconds: Int, operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0, milliseconds)) * 1_000_000)
                guard !Task.isCancelled else { return }
                await operation()
            } catch { }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
