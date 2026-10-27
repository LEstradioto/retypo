import Foundation

/// Messages API shapes for an enhanced run: tool definitions going out,
/// turns and usage coming back.
enum AnthropicWire {
    /// The basic search tool, not the `_20260209` one with dynamic
    /// filtering: that one needs programmatic tool calling, which older
    /// models such as Haiku 4.5 lack, and a rewrite rarely needs it.
    static let webSearchType = "web_search_20250305"
    static let lastRoundNotice = "This is the last research step. Do not call more tools; write the final text now from what you have."
    /// Content blocks that are not tool activity.
    private static let proseTypes: Set<String> = ["text", "thinking", "redacted_thinking"]

    static func tools(_ specs: [ToolSpec], webSearch: Bool) -> [[String: Any]] {
        var tools: [[String: Any]] = specs.map { spec in
            ["name": spec.name, "description": spec.description, "input_schema": spec.parameters]
        }
        if webSearch {
            tools.append(["type": webSearchType, "name": "web_search", "max_uses": AnthropicConversation.webSearchUses])
        }
        return tools
    }

    /// Every result goes in one user message: splitting parallel results
    /// across messages teaches the model to stop calling tools in parallel.
    /// The last-round notice is a text block after the results, never inside
    /// one, where the model would read it as untrusted tool output.
    static func toolResults(_ results: [ToolOutcome], isLastRound: Bool) -> [String: Any] {
        var content: [[String: Any]] = results.map { result in
            ["type": "tool_result", "tool_use_id": result.callID, "content": result.content, "is_error": result.isError]
        }
        if isLastRound { content.append(["type": "text", "text": lastRoundNotice]) }
        return ["role": "user", "content": content]
    }

    static func stopReason(_ response: [String: Any]) -> String? {
        response["stop_reason"] as? String
    }

    static func turn(from response: [String: Any]) throws -> AgentTurn {
        let blocks = response["content"] as? [[String: Any]] ?? []
        switch stopReason(response) {
        case "tool_use": return .toolCalls(toolCalls(in: blocks))
        case "refusal": throw LLMError.emptyCompletion("declined by the model's safety filter\(refusalCategory(response))")
        case "max_tokens": throw LLMError.emptyCompletion("hit the \(AnthropicConversation.maxTokens)-token limit before answering")
        case "pause_turn": throw LLMError.emptyCompletion("web search kept pausing without an answer")
        default: return .answer(try answer(in: blocks, response: response))
        }
    }

    static func toolCalls(in blocks: [[String: Any]]) -> [ToolCall] {
        blocks.compactMap { block in
            guard block["type"] as? String == "tool_use", let id = block["id"] as? String,
                  let name = block["name"] as? String else { return nil }
            return ToolCall(id: id, name: name, arguments: block["input"] as? [String: Any] ?? [:])
        }
    }

    /// The text after the last tool activity. With web search the final
    /// turn also holds the "I'll look that up" lead-in before the search,
    /// which must not end up in the editor. Citations split the answer into
    /// several text blocks; they are joined back.
    static func answer(in blocks: [[String: Any]], response: [String: Any]) throws -> String {
        let lastTool = blocks.lastIndex { !proseTypes.contains($0["type"] as? String ?? "") }
        let tail = lastTool.map { blocks[blocks.index(after: $0)...] } ?? blocks[...]
        let text = tail.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyCompletion(AnthropicBudget.emptyReason(response))
        }
        return text
    }

    /// Cache reads and writes count as input, priced at the full input rate:
    /// the estimate errs high rather than hiding spend.
    static func usage(in response: [String: Any]) -> TokenUsage {
        let usage = response["usage"] as? [String: Any] ?? [:]
        let input = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]
            .reduce(0) { $0 + (usage[$1] as? Int ?? 0) }
        let searches = (usage["server_tool_use"] as? [String: Any])?["web_search_requests"] as? Int
        return TokenUsage(inputTokens: input, outputTokens: usage["output_tokens"] as? Int ?? 0, webSearches: searches)
    }

    private static func refusalCategory(_ response: [String: Any]) -> String {
        guard let category = (response["stop_details"] as? [String: Any])?["category"] as? String else { return "" }
        return " (\(category))"
    }
}
