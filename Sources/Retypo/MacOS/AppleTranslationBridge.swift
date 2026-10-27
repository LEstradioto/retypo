import Foundation
import NaturalLanguage
import SwiftUI
import Translation

/// Session bridge for Apple's on-device Translation framework (macOS 15+).
/// A `TranslationSession` only exists inside a `translationTask` closure, so
/// TranslationCardView attaches the task and this bridge routes jobs to the
/// live session. Jobs resolve exactly once — by the session, by the submit
/// timeout, or when the pump ends — so a stalled system session can never
/// leave the card spinning.
///
/// The session is always configured with an explicit language pair. A nil
/// source makes `prepareTranslation` throw `unableToIdentifyLanguage` and
/// sends `translate` into the same identification path; we identify with
/// NaturalLanguage instead (offline and instant) and gate on
/// `LanguageAvailability` so a missing language pack fails fast with an
/// actionable message rather than blocking on a download UI the panel
/// cannot present.
@available(macOS 15.0, *)
@MainActor
final class AppleTranslationBridge: ObservableObject {
    static let shared = AppleTranslationBridge()

    /// Seconds a job waits for the system session before giving up.
    static let submitTimeoutNanoseconds: UInt64 = 6_000_000_000

    @Published private(set) var configuration: TranslationSession.Configuration?

    struct Job {
        let id: UUID
        let text: String
    }

    private let jobs: AsyncStream<Job>
    private let jobSender: AsyncStream<Job>.Continuation
    private let slots = ContinuationSlots()
    private var configuredPair: String?

    private init() {
        (jobs, jobSender) = AsyncStream.makeStream(of: Job.self)
    }

    func configure(sourceCode: String, targetCode: String) {
        let pair = "\(sourceCode)→\(targetCode)"
        guard configuredPair != pair else { return }
        configuredPair = pair
        DebugLog.log("apple translation session pair=\(pair)")
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: sourceCode),
            target: Locale.Language(identifier: targetCode)
        )
    }

    /// Called from the view's translationTask with a fresh session.
    func pump(_ session: TranslationSession) async {
        DebugLog.log("apple translation session attached")
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
        DebugLog.log("apple translation job timed out id=\(id)")
        slots.resolve(id, with: .failure(LiveTranslationError.appleTimedOut))
    }
}

@available(macOS 15.0, *)
struct AppleTranslationEngine: LiveTranslator {
    @MainActor
    func translate(_ text: String, target: TargetLanguage) async throws -> LiveTranslationResult {
        guard let sourceCode = Self.detectedLanguageCode(of: text) else {
            throw LiveTranslationError.appleCannotIdentifySource
        }
        if target.isSameBaseLanguage(as: sourceCode) {
            DebugLog.log("apple translation no-op: text already in \(target.code)")
            return LiveTranslationResult(text: text, usage: .zero)
        }
        try await Self.requireInstalledAssets(from: sourceCode, to: target.code)
        let bridge = AppleTranslationBridge.shared
        bridge.configure(sourceCode: sourceCode, targetCode: target.code)
        let translated = try await bridge.submit(text)
        return LiveTranslationResult(text: translated, usage: .zero)
    }

    /// Preflight the language pair. `supported` means downloadable but not
    /// present: the download UI cannot present over the panel, so fail fast
    /// with a message the user can act on instead of hanging.
    @MainActor
    private static func requireInstalledAssets(from sourceCode: String, to targetCode: String) async throws {
        let availability = await LanguageAvailability().status(
            from: Locale.Language(identifier: sourceCode),
            to: Locale.Language(identifier: targetCode)
        )
        DebugLog.log("apple translation availability=\(availability) for \(sourceCode)→\(targetCode)")
        switch availability {
        case .installed: return
        case .supported: throw LiveTranslationError.applePackNotInstalled
        case .unsupported: throw LiveTranslationError.appleUnsupportedPair
        }
    }

    /// Source detection runs in NaturalLanguage — offline, instant, and it
    /// sidesteps the Translation framework's identification path that threw
    /// `unableToIdentifyLanguage` for nil-source sessions.
    nonisolated static func detectedLanguageCode(of text: String) -> String? {
        NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
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
