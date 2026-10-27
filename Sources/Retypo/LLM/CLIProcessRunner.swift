import Foundation

struct CLIResult {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32

    /// A CLI that dies before writing its normal output explains itself on
    /// stderr — "not logged in", an unknown flag, a network failure.
    var failureSummary: String {
        let errors = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !errors.isEmpty { return ProviderErrorMessage.summary(errors) }
        let output = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { return ProviderErrorMessage.summary(output) }
        return "exited with code \(exitCode) and no output"
    }
}

/// Runs a local CLI as a one-shot subprocess.
///
/// The panel loads API keys into its *own* environment (`DotEnvLoader` calls
/// `setenv`), and a child process inherits them. Claude Code would then
/// authenticate with `ANTHROPIC_API_KEY` and bill the API instead of the
/// signed-in subscription — which is the whole point of these providers — so
/// provider keys are stripped from the child environment.
enum CLIProcessRunner {
    private static let scrubbedKeys = ProviderKind.allCases.compactMap(\.apiKeyEnvironmentName)
        + ["ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "OPENAI_BASE_URL"]

    static func run(_ tool: String, arguments: [String], timeout: TimeInterval = 180) async throws -> CLIResult {
        guard let executable = CLIExecutableLocator.find(tool) else { throw LLMError.cliNotFound(tool) }
        let process = makeProcess(executable: executable, arguments: arguments)
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice

        async let stdout = drain(output)
        async let stderr = drain(errors)
        try await launch(process, timeout: timeout)
        return CLIResult(standardOutput: await stdout, standardError: await stderr, exitCode: process.terminationStatus)
    }

    private static func makeProcess(executable: URL, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        // A scratch directory keeps the CLI from picking up the project it
        // happens to be launched next to (CLAUDE.md, AGENTS.md, git state).
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.environment = childEnvironment()
        return process
    }

    /// A GUI app's `PATH` is `/usr/bin:/bin:/usr/sbin:/sbin`. The CLIs are
    /// native binaries, but they still shell out (git, ripgrep, node for
    /// npm-based installs), so hand the child the directories the locator
    /// searched instead of the stunted inherited one.
    private static func childEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for key in scrubbedKeys { environment.removeValue(forKey: key) }
        environment["PATH"] = CLIExecutableLocator.defaultSearchPaths.joined(separator: ":")
        return environment
    }

    /// Resumes when the child exits. The watchdog terminates a CLI that hangs
    /// (an interactive prompt we failed to suppress would otherwise wait
    /// forever on a stdin that is never written).
    private static func launch(_ process: Process, timeout: TimeInterval) async throws {
        let watchdog = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning { process.terminate() }
        }
        defer { watchdog.cancel() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do { try process.run() } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Drained concurrently with the run: a child that writes more than the
    /// pipe buffer (64KB) blocks forever if nobody is reading.
    private static func drain(_ pipe: Pipe) async -> String {
        await Task.detached {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
