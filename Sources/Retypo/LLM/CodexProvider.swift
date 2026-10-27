import Foundation

/// Runs edits through the signed-in `codex` CLI, billing the ChatGPT plan.
///
/// Codex has no system-prompt flag, so the instruction is prepended to the
/// text. `--output-last-message` is the only clean way to get the final answer
/// without parsing the whole event stream for it.
final class CodexProvider: LLMProviderClient {
    private let tool = "codex"
    private let locate: (String) -> URL?

    init(locate: @escaping (String) -> URL? = { CLIExecutableLocator.find($0) }) {
        self.locate = locate
    }

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let messageFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("retypo-codex-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: messageFile) }
        let result = try await CLIProcessRunner.run(tool, arguments: arguments(for: request, messageFile: messageFile))
        return try CodexOutput.parse(result, messageFile: messageFile, tool: tool)
    }

    /// See `ClaudeCodeProvider.listModels` — the refresh doubles as the
    /// installed check.
    func listModels(apiKey: String) async throws -> [ProviderModel] {
        guard locate(tool) != nil else { throw LLMError.cliNotFound(tool) }
        return CLIModelCatalog.codex
    }

    /// The user's config.toml may sit at xhigh effort; a rewrite does not
    /// need it, and low cuts several seconds off every run. Research (an
    /// enhanced mode) gets medium to plan its searches. The read-only
    /// sandbox already lets Codex read the paths the prompt lists, so only
    /// web search has to be switched on.
    static func configOverrides(for research: CLIResearchAccess?) -> [String] {
        let effort = ["-c", "model_reasoning_effort=\"\(research == nil ? "low" : "medium")\""]
        return research?.webSearch == true ? effort + ["-c", "web_search=\"live\""] : effort
    }

    func arguments(for request: LLMRequest, messageFile: URL) -> [String] {
        var arguments = [
            "exec",
            "--skip-git-repo-check",   // the scratch cwd is not a repo
            "--ephemeral",             // no session files for a one-shot edit
            "-s", "read-only",         // a text transform never needs to write
            "--json",
            "-o", messageFile.path
        ] + Self.configOverrides(for: request.research)
        if let model = CLIModelCatalog.explicitModel(request.model) {
            arguments += ["-m", model]
        }
        return arguments + ["\(request.system)\n\n\(request.user)"]
    }
}
