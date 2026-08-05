import Foundation

/// Runs edits through the signed-in `claude` CLI, so they bill the Claude
/// subscription instead of an API key.
///
/// Costs ~7s and ~18k tokens of harness context per call (Claude Code sends
/// its own tool definitions and system prompt no matter what `--system-prompt`
/// says), so `AppState.autoRunEnabled` keeps auto-correct off for this
/// provider — see `--bare` in `claude --help` for why the light path is not an
/// option: it reads `ANTHROPIC_API_KEY` only and never the subscription.
final class ClaudeCodeProvider: LLMProviderClient {
    private let tool = "claude"
    private let locate: (String) -> URL?

    init(locate: @escaping (String) -> URL? = { CLIExecutableLocator.find($0) }) {
        self.locate = locate
    }

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let result = try await CLIProcessRunner.run(tool, arguments: arguments(for: request))
        return try ClaudeCodeOutput.parse(result, tool: tool)
    }

    /// Refresh is the one moment we can say the CLI is missing before the
    /// user hits Enter and waits out a run that was never going to work.
    func listModels(apiKey: String) async throws -> [ProviderModel] {
        guard locate(tool) != nil else { throw LLMError.cliNotFound(tool) }
        return CLIModelCatalog.claudeCode
    }

    func arguments(for request: LLMRequest) -> [String] {
        var arguments = [
            "-p", request.user,
            "--system-prompt", request.system,
            "--output-format", "json",
            "--max-turns", "1",
            // Ignore user/project settings: this is a text transform, not a
            // coding session, and hooks or MCP servers would only add latency.
            "--setting-sources", "",
            "--disallowed-tools", "Bash Edit Write Read Glob Grep WebSearch WebFetch Task"
        ]
        if let model = CLIModelCatalog.explicitModel(request.model) {
            arguments += ["--model", model]
        }
        return arguments
    }
}
