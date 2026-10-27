import XCTest
@testable import Retypo

final class AnthropicProviderCachingTests: XCTestCase {
    private typealias F = AnthropicFixtures

    private func send(system: String, usage: [String: Any] = ["input_tokens": 10, "output_tokens": 5]) async throws -> (ScriptedProviderSender, LLMResponse) {
        let sender = ScriptedProviderSender([F.response([F.text("edited")], stop: "end_turn", usage: usage)])
        let provider = AnthropicProvider(memory: RejectedParameterMemory(), sender: sender)
        let request = LLMRequest(provider: .anthropic, model: "claude-haiku-5-5", system: system, user: "text")
        return (sender, try await provider.complete(request, apiKey: "key"))
    }

    /// Inline documents make the system prompt long and identical across runs.
    func testLongSystemPromptsAreCached() async throws {
        let (sender, _) = try await send(system: String(repeating: "doc ", count: AnthropicProvider.cachedSystemCharacters))
        XCTAssertNotNil(sender.posts.first?.body["cache_control"])
    }

    func testShortSystemPromptsAreNotCached() async throws {
        let (sender, _) = try await send(system: "Fix typos.")
        XCTAssertNil(sender.posts.first?.body["cache_control"])
    }

    /// Cached input is still input: leaving it out would hide spend.
    func testCacheTokensCountTowardInput() async throws {
        let usage: [String: Any] = ["input_tokens": 10, "cache_read_input_tokens": 1_000, "cache_creation_input_tokens": 50, "output_tokens": 5]
        let (_, response) = try await send(system: "Fix typos.", usage: usage)
        XCTAssertEqual(response.usage, TokenUsage(inputTokens: 1_060, outputTokens: 5))
    }
}
