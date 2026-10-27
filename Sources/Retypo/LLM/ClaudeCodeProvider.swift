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
        let result = try await CLIProcessRunner.run(tool, arguments: arguments(for: request), workingDirectory: request.research?.workspace)
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
            // Each run would otherwise leave a transcript (the user's text and
            // every file it read) under ~/.claude/projects.
            "--no-session-persistence",
            "--disallowed-tools", ClaudeCodeTools.disallowed(for: request.research)
        ]
        arguments += request.research.map(ClaudeCodeTools.researchArguments) ?? []
        if let model = CLIModelCatalog.explicitModel(request.model) {
            arguments += ["--model", model]
        }
        return arguments
    }
}

/// Which Claude Code tools a run may use. A plain run gets none; an
/// enhanced run may read the attached sources and, when its mode allows,
/// search the web. Nothing ever writes, edits, runs commands or fetches URLs.
enum ClaudeCodeTools {
    static let readTools = ["Read", "Grep", "Glob"]
    /// WebFetch stays off: a planted instruction could send what the model
    /// read to any URL. Search results still arrive as snippets.
    static let neverAllowed = ["Bash", "Edit", "Write", "Task", "WebFetch"]
    static let researchTurns = "12"

    /// Only WebSearch is ever allow-listed. A bare `Read` rule approves reads
    /// anywhere on disk; left unnamed, the read tools stay limited to the
    /// working directory and the `--add-dir` folders, and the CLI denies the rest.
    static func allowed(for research: CLIResearchAccess?) -> [String] {
        research?.webSearch == true ? ["WebSearch"] : []
    }

    static func disallowed(for research: CLIResearchAccess?) -> String {
        let reads = research?.readsFiles == true ? [] : readTools
        let web = research?.webSearch == true ? [] : ["WebSearch"]
        return (neverAllowed + reads + web).joined(separator: " ")
    }

    /// `--add-dir` takes several values, so it goes after every flag whose
    /// value could be mistaken for a directory.
    static func researchArguments(_ research: CLIResearchAccess) -> [String] {
        let tools = research.webSearch ? ["--allowed-tools", allowed(for: research).joined(separator: " ")] : []
        return research.folders.isEmpty ? tools : tools + ["--add-dir"] + research.folders
    }
}
