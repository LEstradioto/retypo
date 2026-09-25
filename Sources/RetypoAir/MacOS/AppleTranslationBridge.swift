import Foundation
import SwiftUI
import Translation

/// Session bridge for Apple's on-device Translation framework (macOS 15+).
/// A `TranslationSession` only exists inside a `translationTask` closure, so
/// TranslationCardView attaches the task and this bridge routes jobs to the
/// live session. Jobs resolve exactly once: by the session, by the submit
/// timeout, or when the pump ends — a stalled system session (consent sheet
/// that cannot present over the panel, missing language assets) surfaces as
/// an error so FallbackTranslator can retry through the LLM instead of
/// spinning forever.
@available(macOS 15.0, *)
@MainActor
final class AppleTranslationBridge: ObservableObject {
    static let shared = AppleTranslationBridge()

    /// Seconds a job waits for the system session before giving up.
    static let submitTimeoutNanoseconds: UInt64 = 4_000_000_000

    @Published private(set) var configuration: TranslationSession.Configuration?

    struct Job {
        let id: UUID
        let text: String
    }

    private let jobs: AsyncStream<Job>
    private let jobSender: AsyncStream<Job>.Continuation
    private let slots = ContinuationSlots()
    private var configuredTarget: String?

    private init() {
        (jobs, jobSender) = AsyncStream.makeStream(of: Job.self)
    }

    func configure(target: TargetLanguage) {
        guard configuredTarget != target.code else { return }
        configuredTarget = target.code
        configuration = TranslationSession.Configuration(
            source: nil,
            target: Locale.Language(identifier: target.code)
        )
    }

    /// Called from the view's translationTask with a fresh session.
    func pump(_ session: TranslationSession) async {
        DebugLog.log("apple translation session attached")
        do {
            try await session.prepareTranslation()
            DebugLog.log("apple translation session prepared")
        } catch {
            DebugLog.log("apple translation prepare failed: \(error)")
        }
        defer { slots.resolveAll(with: .failure(LiveTranslationError.appleTimedOut)) }
        for await job in jobs {
            do {
                let response = try await session.translate(job.text)
                DebugLog.log("apple translation ok id=\(job.id) len=\(response.targetText.count)")
                slots.resolve(job.id, with: .success(response.targetText))
            } catch {
                DebugLog.log("apple translation failed id=\(job.id): \(error)")
                slots.resolve(job.id, with: .failure(error))
            }
        }
    }

    func submit(_ text: String) async throws -> String {
        let id = UUID()
        DebugLog.log("apple translation job submitted id=\(id) len=\(text.count)")
        return try await withCheckedThrowingContinuation { continuation in
            slots.register(id, continuation)
            jobSender.yield(Job(id: id, text: text))
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.submitTimeoutNanoseconds)
                self?.timeout(id: id)
            }
        }
    }

    private func timeout(id: UUID) {
        guard slots.pendingCount > 0 else { return }
        DebugLog.log("apple translation job timed out id=\(id)")
        slots.resolve(id, with: .failure(LiveTranslationError.appleTimedOut))
    }
}

@available(macOS 15.0, *)
struct AppleTranslationEngine: LiveTranslator {
    @MainActor
    func translate(_ text: String, target: TargetLanguage) async throws -> LiveTranslationResult {
        let bridge = AppleTranslationBridge.shared
        bridge.configure(target: target)
        let translated = try await bridge.submit(text)
        return LiveTranslationResult(text: translated, usage: .zero)
    }
}

/// Attaches the Apple translationTask to the card. No-op below macOS 15.
extension View {
    @ViewBuilder
    func appleTranslationTask() -> some View {
        if #available(macOS 15.0, *) {
            modifier(AppleTranslationTaskModifier())
        } else {
            self
        }
    }
}

@available(macOS 15.0, *)
private struct AppleTranslationTaskModifier: ViewModifier {
    @ObservedObject private var bridge = AppleTranslationBridge.shared

    func body(content: Content) -> some View {
        content.translationTask(bridge.configuration) { session in
            await bridge.pump(session)
        }
    }
}
