import Foundation

/// What an enhanced Anthropic run sends with every request.
struct AnthropicResearchSetup {
    let model: String
    let system: String
    let user: String
    /// Empty for a web-only mode.
    let tools: [ToolSpec]
    let webSearch: Bool
}

/// An enhanced run on the Messages API. The reference tools run locally,
/// web search runs on Anthropic's side, and adaptive thinking (on by
/// default on the Claude 5 models, Haiku 5.5 included) reasons in between.
///
/// The transcript is append-only. The 5.5 models reject a replayed thinking
/// block once anything before it changed, so every assistant turn goes back
/// exactly as received and nothing earlier is ever edited.
final class AnthropicConversation: AgentConversation {
    static let maxTokens = 16_000
    /// The server's search loop pauses after about ten iterations; resuming
    /// is just sending the paused turn back.
    static let pauseResumes = 3
    static let webSearchUses = 5
    /// Not streamed: nothing arrives until the whole turn, searches
    /// included, is done, which can take well past URLSession's 60s.
    static let timeout: TimeInterval = 180

    private let setup: AnthropicResearchSetup
    private let apiKey: String
    private let sender: ProviderSending
    private var messages: [[String: Any]]
    private(set) var usage = TokenUsage.zero

    init(setup: AnthropicResearchSetup, apiKey: String, sender: ProviderSending) {
        self.setup = setup
        self.apiKey = apiKey
        self.sender = sender
        messages = [["role": "user", "content": setup.user]]
    }

    func next(after results: [ToolOutcome], isLastRound: Bool) async throws -> AgentTurn {
        if !results.isEmpty { messages.append(AnthropicWire.toolResults(results, isLastRound: isLastRound)) }
        var response = try await send()
        var resumes = 0
        while AnthropicWire.stopReason(response) == "pause_turn", resumes < Self.pauseResumes {
            resumes += 1
            response = try await send()
        }
        return try AnthropicWire.turn(from: response)
    }

    private func send() async throws -> [String: Any] {
        let response = try await sender.send(post(), model: setup.model)
        usage = usage.adding(AnthropicWire.usage(in: response))
        messages.append(["role": "assistant", "content": response["content"] as? [[String: Any]] ?? []])
        return response
    }

    private func post() -> ProviderPost {
        ProviderPost(
            url: URL(staticString: "https://api.anthropic.com/v1/messages"),
            headers: ["x-api-key": apiKey, "anthropic-version": "2023-06-01"],
            body: body(),
            optionalKeys: ["cache_control"],
            timeout: Self.timeout
        )
    }

    /// One explicit cache breakpoint on the system prompt (which carries
    /// inline documents) and automatic caching for the growing history, so
    /// each round re-reads the previous ones at the cache price.
    private func body() -> [String: Any] {
        [
            "model": setup.model,
            "max_tokens": Self.maxTokens,
            "system": [["type": "text", "text": setup.system, "cache_control": ["type": "ephemeral"]]],
            "messages": messages,
            "tools": AnthropicWire.tools(setup.tools, webSearch: setup.webSearch),
            "cache_control": ["type": "ephemeral"]
        ]
    }
}
