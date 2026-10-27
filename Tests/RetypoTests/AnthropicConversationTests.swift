import XCTest
@testable import Retypo

final class AnthropicConversationTests: XCTestCase {
    private typealias F = AnthropicFixtures

    private func conversation(_ sender: ScriptedProviderSender, webSearch: Bool = true) -> AnthropicConversation {
        let setup = AnthropicResearchSetup(model: "claude-haiku-5-5", system: "SYSTEM", user: "Text to edit:\n\nhi",
                                           tools: ReferenceTools.all, webSearch: webSearch)
        return AnthropicConversation(setup: setup, apiKey: "key", sender: sender)
    }

    func testFirstRequestCachesTheSystemPromptAndOffersEveryTool() async throws {
        let sender = ScriptedProviderSender([F.response([F.text("done")], stop: "end_turn")])
        _ = try await conversation(sender).next(after: [], isLastRound: false)
        let body = try XCTUnwrap(sender.posts.first?.body)
        let system = try XCTUnwrap((body["system"] as? [[String: Any]])?.first)
        XCTAssertEqual(system["text"] as? String, "SYSTEM")
        XCTAssertNotNil(system["cache_control"])
        XCTAssertNotNil(body["cache_control"], "the growing history is cached for the next round")
        XCTAssertNil(body["temperature"], "Claude 5 models reject non-default sampling")
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.compactMap { $0["name"] as? String }, ["list_files", "search_files", "read_file", "web_search"])
        XCTAssertEqual(tools.last?["type"] as? String, "web_search_20250305")
        XCTAssertEqual(sender.posts.first?.timeout, AnthropicConversation.timeout)
    }

    func testWebOffSendsNoSearchTool() async throws {
        let sender = ScriptedProviderSender([F.response([F.text("done")], stop: "end_turn")])
        _ = try await conversation(sender, webSearch: false).next(after: [], isLastRound: false)
        let tools = try XCTUnwrap(sender.posts.first?.body["tools"] as? [[String: Any]])
        XCTAssertFalse(tools.contains { $0["name"] as? String == "web_search" })
    }

    func testToolUseBecomesToolCalls() async throws {
        let sender = ScriptedProviderSender([F.response([F.thinking, F.toolUse(id: "tu1", name: "search_files", input: ["query": "refund"])], stop: "tool_use")])
        guard case .toolCalls(let calls) = try await conversation(sender).next(after: [], isLastRound: false) else {
            return XCTFail("expected tool calls")
        }
        XCTAssertEqual(calls.map(\.id), ["tu1"])
        XCTAssertEqual(calls.first?.string("query"), "refund")
    }

    /// Thinking blocks must go back exactly as received, and every result
    /// of a turn goes in one user message.
    func testResultsFollowTheUnchangedAssistantTurn() async throws {
        let sender = ScriptedProviderSender([
            F.response([F.thinking, F.toolUse(id: "tu1", name: "read_file", input: ["path": "a.md"]), F.toolUse(id: "tu2", name: "list_files", input: [:])], stop: "tool_use"),
            F.response([F.text("final")], stop: "end_turn")
        ])
        let chat = conversation(sender)
        _ = try await chat.next(after: [], isLastRound: false)
        let results = [ToolOutcome(callID: "tu1", content: "body", isError: false), ToolOutcome(callID: "tu2", content: "oops", isError: true)]
        _ = try await chat.next(after: results, isLastRound: false)
        let messages = sender.messages(ofPost: 1)
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["user", "assistant", "user"])
        let assistant = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(assistant.first?["signature"] as? String, "sig-abc")
        let resultBlocks = try XCTUnwrap(messages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(resultBlocks.compactMap { $0["tool_use_id"] as? String }, ["tu1", "tu2"])
        XCTAssertEqual(resultBlocks.last?["is_error"] as? Bool, true)
    }

    func testLastRoundAsksForTheAnswerAfterTheResults() async throws {
        let sender = ScriptedProviderSender([
            F.response([F.toolUse(id: "tu1", name: "list_files", input: [:])], stop: "tool_use"),
            F.response([F.text("final")], stop: "end_turn")
        ])
        let chat = conversation(sender)
        _ = try await chat.next(after: [], isLastRound: false)
        _ = try await chat.next(after: [ToolOutcome(callID: "tu1", content: "x", isError: false)], isLastRound: true)
        let blocks = try XCTUnwrap(sender.messages(ofPost: 1).last?["content"] as? [[String: Any]])
        XCTAssertEqual(blocks.map { $0["type"] as? String }, ["tool_result", "text"])
        XCTAssertEqual(blocks.last?["text"] as? String, AnthropicWire.lastRoundNotice)
    }

    /// A paused server-side search resumes by sending the paused turn back,
    /// with no new user message.
    func testPausedTurnResumesWithoutANewUserMessage() async throws {
        let sender = ScriptedProviderSender([
            F.response([["type": "server_tool_use", "id": "srv1", "name": "web_search", "input": ["query": "x"]]], stop: "pause_turn"),
            F.response([F.text("resumed answer")], stop: "end_turn")
        ])
        guard case .answer(let text) = try await conversation(sender).next(after: [], isLastRound: false) else {
            return XCTFail("expected an answer")
        }
        XCTAssertEqual(text, "resumed answer")
        XCTAssertEqual(sender.messages(ofPost: 1).map { $0["role"] as? String }, ["user", "assistant"])
    }

    /// The editor gets the rewrite, not "Let me look that up".
    func testAnswerDropsTheLeadInBeforeAWebSearch() async throws {
        let content: [[String: Any]] = [
            F.text("Let me check the current price."),
            ["type": "server_tool_use", "id": "srv1", "name": "web_search", "input": ["query": "price"]],
            ["type": "web_search_tool_result", "tool_use_id": "srv1", "content": []],
            F.text("It costs "), ["type": "text", "text": "$5", "citations": [["type": "web_search_result_location"]]], F.text(" now.")
        ]
        let sender = ScriptedProviderSender([F.response(content, stop: "end_turn")])
        guard case .answer(let text) = try await conversation(sender).next(after: [], isLastRound: false) else {
            return XCTFail("expected an answer")
        }
        XCTAssertEqual(text, "It costs $5 now.")
    }

    func testUsageAddsCachedInputAndWebSearchesAcrossRounds() async throws {
        let usage: [String: Any] = ["input_tokens": 100, "cache_creation_input_tokens": 20, "cache_read_input_tokens": 30,
                                    "output_tokens": 7, "server_tool_use": ["web_search_requests": 2]]
        let sender = ScriptedProviderSender([
            F.response([F.toolUse(id: "tu1", name: "list_files", input: [:])], stop: "tool_use", usage: usage),
            F.response([F.text("done")], stop: "end_turn", usage: usage)
        ])
        let chat = conversation(sender)
        _ = try await chat.next(after: [], isLastRound: false)
        _ = try await chat.next(after: [ToolOutcome(callID: "tu1", content: "x", isError: false)], isLastRound: false)
        XCTAssertEqual(chat.usage, TokenUsage(inputTokens: 300, outputTokens: 14, webSearches: 4))
    }

    func testRefusalExplainsItself() async {
        let refusal: [String: Any] = ["content": [], "stop_reason": "refusal", "stop_details": ["type": "refusal", "category": "cyber"]]
        do {
            _ = try await conversation(ScriptedProviderSender([refusal])).next(after: [], isLastRound: false)
            XCTFail("a refusal must not become an empty answer")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("cyber"))
        }
    }
}
