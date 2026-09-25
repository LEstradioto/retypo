import Foundation

struct LiveTranslationResult {
    let text: String
    let usage: TokenUsage
}

/// Engine seam for the experimental live-translation card. Implementations:
/// LLMTranslator (always available), AppleTranslationEngine (macOS 15+),
/// FallbackTranslator (auto mode: Apple first, LLM on failure). Main-actor
/// isolated because every caller is AppState.
protocol LiveTranslator {
    @MainActor func translate(_ text: String, target: TargetLanguage) async throws -> LiveTranslationResult
}

enum LiveTranslationEngine: String, Codable, CaseIterable {
    case auto
    case apple
    case llm

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .apple: return "Apple (on-device)"
        case .llm: return "LLM model"
        }
    }
}

enum LiveTranslationError: Error, LocalizedError, Equatable {
    case noModel
    case appleTimedOut

    var errorDescription: String? {
        switch self {
        case .noModel: return "Choose a model before live translation"
        case .appleTimedOut: return "Apple Translation stalled; try the LLM engine"
        }
    }
}

/// Translates through the same router the modes use: hardened rewrite
/// posture, user's model, user's cost tracker.
struct LLMTranslator: LiveTranslator {
    let router: LLMRouter
    let provider: ProviderKind
    let model: String
    let preamble: String

    @MainActor
    func translate(_ text: String, target: TargetLanguage) async throws -> LiveTranslationResult {
        guard !model.isEmpty else { throw LiveTranslationError.noModel }
        let llmRequest = request(text: text, target: target)
        let response = try await router.complete(llmRequest)
        return LiveTranslationResult(
            text: response.text.trimmingCharacters(in: .whitespacesAndNewlines),
            usage: response.usage
        )
    }

    func request(text: String, target: TargetLanguage) -> LLMRequest {
        LLMRequest(
            provider: provider,
            model: model,
            system: PromptTemplates.actionSystem(
                instruction: "Translate the text to natural \(target.name). Return only the translated text.",
                preamble: preamble
            ),
            user: PromptTemplates.userMessage(text),
            maxTokens: max(400, min(4_000, text.count * 2)),
            temperature: 0
        )
    }
}

/// Tries the primary engine and falls back on any failure. Auto mode pairs
/// Apple (on-device, real-time) with the LLM (always available).
struct FallbackTranslator: LiveTranslator {
    let primary: LiveTranslator
    let fallback: LiveTranslator

    @MainActor
    func translate(_ text: String, target: TargetLanguage) async throws -> LiveTranslationResult {
        do {
            return try await primary.translate(text, target: target)
        } catch {
            return try await fallback.translate(text, target: target)
        }
    }
}
