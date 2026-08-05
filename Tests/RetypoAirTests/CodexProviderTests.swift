import XCTest
@testable import RetypoAir

final class CodexProviderTests: XCTestCase {
    private let provider = CodexProvider()
    private let messageFile = URL(fileURLWithPath: "/tmp/retypo-codex-test.txt")

    private func request(model: String) -> LLMRequest {
        LLMRequest(provider: .codex, model: model, system: "Fix typos.", user: "helo wrld")
    }

    /// Codex has no system-prompt flag, so the instruction is prepended and
    /// the whole thing is the final positional argument.
    func testPromptCombinesInstructionAndTextAsTheLastArgument() {
        let arguments = provider.arguments(for: request(model: "default"), messageFile: messageFile)
        XCTAssertEqual(arguments.first, "exec")
        XCTAssertEqual(arguments.last, "Fix typos.\n\nhelo wrld")
    }

    func testRunsSandboxedAndWithoutSessionFiles() {
        let arguments = provider.arguments(for: request(model: "default"), messageFile: messageFile)
        XCTAssertEqual(CLIArguments.value(after: "-s", in: arguments), "read-only")
        XCTAssertTrue(arguments.contains("--ephemeral"))
        XCTAssertTrue(arguments.contains("--skip-git-repo-check"))
        XCTAssertEqual(CLIArguments.value(after: "-o", in: arguments), messageFile.path)
    }

    /// A rewrite does not need the user's configured xhigh effort.
    func testOverridesReasoningEffort() {
        let arguments = provider.arguments(for: request(model: "default"), messageFile: messageFile)
        XCTAssertEqual(CLIArguments.value(after: "-c", in: arguments), "model_reasoning_effort=\"low\"")
    }

    func testDefaultModelSendsNoModelFlag() {
        XCTAssertFalse(provider.arguments(for: request(model: "default"), messageFile: messageFile).contains("-m"))
    }

    func testExplicitModelIsPassedThrough() {
        let arguments = provider.arguments(for: request(model: "gpt-5.6-sol"), messageFile: messageFile)
        XCTAssertEqual(CLIArguments.value(after: "-m", in: arguments), "gpt-5.6-sol")
    }

    /// Event shapes captured from a real `codex exec --json` run.
    func testReadsAnswerFromTheMessageFileAndUsageFromTheEventStream() throws {
        let file = try temporaryFile(contents: "The quick brown fox.\n")
        defer { try? FileManager.default.removeItem(at: file) }
        let stdout = """
        {"type": "thread.started", "thread_id": "abc"}
        {"type": "turn.completed", "usage": {"input_tokens": 16206, "cached_input_tokens": 9984, "output_tokens": 5, "reasoning_output_tokens": 12}}
        """
        let response = try CodexOutput.parse(cli(stdout), messageFile: file, tool: "codex")
        XCTAssertEqual(response.text, "The quick brown fox.")
        XCTAssertEqual(response.usage.inputTokens, 16_206)
        XCTAssertEqual(response.usage.outputTokens, 17)
    }

    /// Codex nests the upstream API error as a JSON string inside `message`.
    func testUnwrapsTheNestedUpstreamErrorSentence() {
        let stdout = #"""
        {"type": "error", "message": "{\"type\":\"error\",\"status\":400,\"error\":{\"type\":\"invalid_request_error\",\"message\":\"The 'gpt-5.2' model is not supported when using Codex with a ChatGPT account.\"}}"}
        """#
        XCTAssertThrowsError(try CodexOutput.parse(cli(stdout), messageFile: messageFile, tool: "codex")) { error in
            XCTAssertTrue(error.localizedDescription.contains("not supported when using Codex"), error.localizedDescription)
        }
    }

    func testMissingMessageFileFallsBackToStderr() {
        let cli = CLIResult(standardOutput: "", standardError: "Not logged in. Run codex login.", exitCode: 1)
        XCTAssertThrowsError(try CodexOutput.parse(cli, messageFile: messageFile, tool: "codex")) { error in
            XCTAssertTrue(error.localizedDescription.contains("codex login"), error.localizedDescription)
        }
    }

    func testRefreshReportsAMissingCLI() async {
        let provider = CodexProvider(locate: { _ in nil })
        do {
            _ = try await provider.listModels(apiKey: "")
            XCTFail("expected a missing-CLI failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("codex"), error.localizedDescription)
        }
    }

    func testRefreshListsModelsWhenTheCLIIsInstalled() async throws {
        let provider = CodexProvider(locate: { tool in URL(fileURLWithPath: "/usr/bin/\(tool)") })
        let models = try await provider.listModels(apiKey: "")
        XCTAssertEqual(models.first?.id, "default")
    }

    private func cli(_ stdout: String) -> CLIResult {
        CLIResult(standardOutput: stdout, standardError: "", exitCode: 0)
    }

    private func temporaryFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codex-test-\(UUID().uuidString).txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
