import Foundation

/// Parses `claude -p --output-format json`, whose single JSON object carries
/// the answer in `result` and the token counts in `usage`.
enum ClaudeCodeOutput {
    static func parse(_ result: CLIResult, tool: String) throws -> LLMResponse {
        guard let object = jsonObject(result.standardOutput) else {
            throw LLMError.cliFailed(tool, result.failureSummary)
        }
        if object["is_error"] as? Bool == true {
            throw LLMError.cliFailed(tool, object["result"] as? String ?? "unknown error")
        }
        guard let text = object["result"] as? String, !text.isEmpty else {
            throw LLMError.emptyCompletion("stop reason: \(object["stop_reason"] as? String ?? "unknown")")
        }
        return LLMResponse(text: text, usage: usage(object["usage"] as? [String: Any]))
    }

    private static func jsonObject(_ output: String) -> [String: Any]? {
        guard let data = output.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Cache reads and writes are billed against the subscription's limits
    /// just like fresh input, so they are counted as input here.
    private static func usage(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage else { return .zero }
        let input = (usage["input_tokens"] as? Int ?? 0)
            + (usage["cache_read_input_tokens"] as? Int ?? 0)
            + (usage["cache_creation_input_tokens"] as? Int ?? 0)
        return TokenUsage(inputTokens: input, outputTokens: usage["output_tokens"] as? Int ?? 0)
    }
}
