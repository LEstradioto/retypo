import Foundation

/// Keeps the model picker to models that can actually answer a text edit.
///
/// `/v1/models` returns the whole account catalogue — 130+ entries on OpenAI —
/// including speech, image, embedding and moderation endpoints that fail the
/// moment you send them a prompt. Picking one of those was indistinguishable
/// from a real outage in the panel's one-line status bar.
enum ModelCatalogFilter {
    /// Matched as substrings against the lowercased model id.
    private static let excluded = [
        "embedding", "moderation",                              // not chat endpoints
        "whisper", "tts", "audio", "transcribe", "realtime",    // speech
        "image", "dall-e", "sora",                              // vision/video generation
        "guard", "orpheus",                                     // classifiers / TTS on Groq
        "davinci", "babbage",                                   // legacy completions-only
        "computer-use", "deep-research"                         // need a tool loop we don't run
    ]

    static func isTextModel(_ id: String) -> Bool {
        let lowered = id.lowercased()
        return !excluded.contains { lowered.contains($0) }
    }
}
