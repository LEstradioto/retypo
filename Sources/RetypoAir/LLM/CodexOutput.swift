import Foundation

/// Parses a `codex exec --json` run: the final answer is written to the
/// `--output-last-message` file, while token counts and failures arrive as
/// JSONL events on stdout (`turn.completed`, `error`, `turn.failed`).
enum CodexOutput {
    static func parse(_ result: CLIResult, messageFile: URL, tool: String) throws -> LLMResponse {
        let events = jsonEvents(result.standardOutput)
        if let failure = failure(in: events) { throw LLMError.cliFailed(tool, failure) }
        guard let text = message(at: messageFile) else {
            throw LLMError.cliFailed(tool, result.failureSummary)
        }
        return LLMResponse(text: text, usage: usage(in: events))
    }

    private static func jsonEvents(_ output: String) -> [[String: Any]] {
        output.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
    }

    /// Codex nests the upstream API error as a JSON string inside `message`,
    /// so run it back through the shared summariser to reach the sentence.
    private static func failure(in events: [[String: Any]]) -> String? {
        for event in events where event["type"] as? String == "error" {
            guard let message = event["message"] as? String else { continue }
            return ProviderErrorMessage.summary(message)
        }
        return nil
    }

    private static func message(at file: URL) -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func usage(in events: [[String: Any]]) -> TokenUsage {
        guard let turn = events.last(where: { $0["type"] as? String == "turn.completed" }),
              let usage = turn["usage"] as? [String: Any] else { return .zero }
        let output = (usage["output_tokens"] as? Int ?? 0) + (usage["reasoning_output_tokens"] as? Int ?? 0)
        return TokenUsage(inputTokens: usage["input_tokens"] as? Int ?? 0, outputTokens: output)
    }
}
