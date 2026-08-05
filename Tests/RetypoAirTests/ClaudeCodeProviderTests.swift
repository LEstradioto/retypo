import XCTest
@testable import RetypoAir

final class ClaudeCodeProviderTests: XCTestCase {
    private let provider = ClaudeCodeProvider()

    private func request(model: String) -> LLMRequest {
        LLMRequest(provider: .claudeCode, model: model, system: "Fix typos.", user: "helo wrld")
    }

    func testArgumentsRunOneNonInteractiveTurnWithTheModeInstruction() {
        let arguments = provider.arguments(for: request(model: "default"))
        XCTAssertEqual(arguments.first, "-p")
        XCTAssertTrue(arguments.contains("helo wrld"))
        XCTAssertEqual(CLIArguments.value(after: "--system-prompt", in: arguments), "Fix typos.")
        XCTAssertEqual(CLIArguments.value(after: "--max-turns", in: arguments), "1")
        XCTAssertEqual(CLIArguments.value(after: "--output-format", in: arguments), "json")
    }

    /// `default` means "use whatever the CLI is configured with", so no flag.
    func testDefaultModelSendsNoModelFlag() {
        XCTAssertFalse(provider.arguments(for: request(model: "default")).contains("--model"))
    }

    func testExplicitModelIsPassedThrough() {
        XCTAssertEqual(CLIArguments.value(after: "--model", in: provider.arguments(for: request(model: "haiku"))), "haiku")
    }

    /// Shape captured from a real `claude -p --output-format json` run.
    func testParsesResultAndCountsCacheTokensAsInput() throws {
        let json = #"""
        {"is_error":false,"result":"The quick brown fox.","usage":{"input_tokens":10,"cache_creation_input_tokens":2580,"cache_read_input_tokens":15249,"output_tokens":164}}
        """#
        let response = try ClaudeCodeOutput.parse(result(stdout: json), tool: "claude")
        XCTAssertEqual(response.text, "The quick brown fox.")
        XCTAssertEqual(response.usage.inputTokens, 17_839)
        XCTAssertEqual(response.usage.outputTokens, 164)
    }

    func testErrorResultBecomesAReadableFailure() {
        let json = #"{"is_error":true,"result":"Credit balance is too low"}"#
        assertFailure(try ClaudeCodeOutput.parse(result(stdout: json), tool: "claude"), contains: "Credit balance")
    }

    /// Not signed in, or a rejected flag: the CLI writes to stderr and never
    /// emits JSON.
    func testNonJSONOutputSurfacesStderr() {
        let cli = CLIResult(standardOutput: "", standardError: "Invalid API key · Run /login", exitCode: 1)
        assertFailure(try ClaudeCodeOutput.parse(cli, tool: "claude"), contains: "Run /login")
    }

    func testSilentFailureMentionsTheExitCode() {
        let cli = CLIResult(standardOutput: "", standardError: "", exitCode: 127)
        assertFailure(try ClaudeCodeOutput.parse(cli, tool: "claude"), contains: "127")
    }

    private func result(stdout: String) -> CLIResult {
        CLIResult(standardOutput: stdout, standardError: "", exitCode: 0)
    }

    private func assertFailure(_ expression: @autoclosure () throws -> LLMResponse, contains needle: String) {
        XCTAssertThrowsError(try expression()) { error in
            XCTAssertTrue(error.localizedDescription.contains(needle), error.localizedDescription)
        }
    }
}

/// Reads the value that follows a flag, so argument tests stay readable.
enum CLIArguments {
    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
