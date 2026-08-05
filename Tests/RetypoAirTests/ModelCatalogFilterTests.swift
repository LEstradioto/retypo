import XCTest
@testable import RetypoAir

final class ModelCatalogFilterTests: XCTestCase {
    func testKeepsTextModels() {
        for id in ["gpt-5.2", "gpt-4o", "o3", "llama-3.3-70b-versatile", "openai/gpt-oss-120b", "anthropic/claude-opus-5"] {
            XCTAssertTrue(ModelCatalogFilter.isTextModel(id), id)
        }
    }

    /// These answer 400 (or worse, silence) the moment the panel sends a prompt.
    func testDropsNonChatEndpoints() {
        for id in ["text-embedding-3-small", "whisper-large-v3", "gpt-4o-mini-tts", "gpt-image-1",
                   "omni-moderation-latest", "gpt-realtime", "gpt-transcribe", "sora-2",
                   "meta-llama/llama-prompt-guard-2-22m", "davinci-002", "computer-use-preview",
                   "o3-deep-research"] {
            XCTAssertFalse(ModelCatalogFilter.isTextModel(id), id)
        }
    }
}
