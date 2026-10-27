import Foundation

/// Runs edits through the signed-in `claude` CLI, so they bill the Claude
/// subscription instead of an API key.
///
/// Costs ~7s and ~18k tokens of harness context per call (Claude Code sends
/// its own tool definitions and system prompt no matter what `--system-prompt`
/// says) — every run is manual (Enter), never on a typing pause. See `--bare`
/// in `claude --help` for why the light path is not an option: it reads
/// `ANTHROPIC_API_KEY` only and never the subscription.
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
            "--max-turns", request.research == nil ? "1" : ClaudeCodeTools.researchTurns,
            // Ignore user/project settings: this is a text transform, not a
            // coding session, and hooks or MCP servers would only add latency.
            "--setting-sources", "",
            "--disallowed-tools", ClaudeCodeTools.disallowed(for: request.research)
        ]
        if let research = request.research {
            arguments += ClaudeCodeTools.researchArguments(research)
        }
        if let model = CLIModelCatalog.explicitModel(request.model) {
            arguments += ["--model", model]
        }
        return arguments
    }
}

/// Which Claude Code tools a run may use. A plain run gets none; an
/// enhanced run may read the attached folders and, when its mode allows,
/// search the web. Nothing ever writes, edits or runs commands.
enum ClaudeCodeTools {
    static let readTools = ["Read", "Grep", "Glob"]
    static let webTools = ["WebSearch", "WebFetch"]
    static let neverAllowed = ["Bash", "Edit", "Write", "Task"]
    static let researchTurns = "12"

    static func allowed(for research: CLIResearchAccess?) -> [String] {
        guard let research else { return [] }
        return (research.folders.isEmpty ? [] : readTools) + (research.webSearch ? webTools : [])
    }

    static func disallowed(for research: CLIResearchAccess?) -> String {
        let allowed = Set(allowed(for: research))
        return (neverAllowed + readTools + webTools).filter { !allowed.contains($0) }.joined(separator: " ")
    }

    /// `--add-dir` takes several values, so it goes after every flag whose
    /// value could be mistaken for a directory.
    static func researchArguments(_ research: CLIResearchAccess) -> [String] {
        let tools = ["--allowed-tools", allowed(for: research).joined(separator: " ")]
        return research.folders.isEmpty ? tools : tools + ["--add-dir"] + research.folders
    }
}
