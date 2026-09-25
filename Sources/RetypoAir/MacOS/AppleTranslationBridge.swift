import Foundation
import SwiftUI
import Translation

/// Session bridge for Apple's on-device Translation framework (macOS 15+).
/// A `TranslationSession` only exists inside a `translationTask` closure, so
/// TranslationCardView attaches the task and this bridge routes jobs to the
/// live session. Failures (assets missing, unsupported pair) throw so the
/// FallbackTranslator can retry through the LLM.
@available(macOS 15.0, *)
@MainActor
final class AppleTranslationBridge: ObservableObject {
    static let shared = AppleTranslationBridge()

    @Published private(set) var configuration: TranslationSession.Configuration?

    struct Job {
        let text: String
        let continuation: CheckedContinuation<String, Error>
    }

    private let jobs: AsyncStream<Job>
    private let jobSender: AsyncStream<Job>.Continuation

    private init() {
        (jobs, jobSender) = AsyncStream.makeStream(of: Job.self)
    }

    func configure(target: TargetLanguage) {
        let config = TranslationSession.Configuration(
            source: nil,
            target: Locale.Language(identifier: target.code)
        )
        guard config != configuration else { return }
        configuration = config
    }

    /// Called from the view's translationTask with a fresh session.
    func pump(_ session: TranslationSession) async {
        for await job in jobs {
            do {
                let response = try await session.translate(job.text)
                job.continuation.resume(returning: response.targetText)
            } catch {
                job.continuation.resume(throwing: error)
            }
        }
    }

    func submit(_ text: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            jobSender.yield(Job(text: text, continuation: continuation))
        }
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
