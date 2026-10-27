import XCTest
@testable import Retypo

/// Calls the real providers. Skipped unless `RETYPO_LIVE_TESTS=1`; costs a
/// few cents on Haiku 5.5 plus Claude Code / Codex subscription usage:
///
///     set -a; source ~/.retypo/.env; set +a
///     RETYPO_LIVE_TESTS=1 swift test --filter LiveEnhancedSmokeTests
final class LiveEnhancedSmokeTests: XCTestCase {
    private var fixture: ReferenceFixture!
    private let fact = "O prazo de reembolso do plano Clínica é de 9 dias úteis."
    private let question = "oi, qual o prazo de reembolso do plano clinica? to esperando faz tempo"
    private let instruction = "Rewrite the message as a short, polite reply from support (Brazilian Portuguese) that answers it with the exact deadline from the reference sources."

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RETYPO_LIVE_TESTS"] == "1", "set RETYPO_LIVE_TESTS=1 to call the real providers")
        _ = DotEnvLoader.load()
        fixture = try ReferenceFixture()
    }

    override func tearDown() {
        fixture?.remove()
    }

    private func request(_ provider: ProviderKind, model: String) -> LLMRequest {
        LLMRequest(provider: provider, model: model,
                   system: PromptTemplates.actionSystem(instruction: instruction),
                   user: PromptTemplates.userMessage(question), maxTokens: 800, temperature: 0.2)
    }

    private func run(_ request: LLMRequest, _ enhancement: ModeEnhancement) async throws -> LLMResponse {
        let started = Date()
        let response = try await LLMRouter().completeEnhanced(request, enhancement: enhancement) { print("LIVE progress: \($0.label)") }
        print("LIVE \(request.provider.rawValue) \(String(format: "%.1fs", Date().timeIntervalSince(started))) usage=\(response.usage)\nLIVE text: \(response.text)")
        return response
    }

    private func largeFolder() throws -> ModeEnhancement {
        let filler = (1...2_500).map { "Linha \($0): política geral sem relação com prazos." }.joined(separator: "\n")
        try fixture.write("kb/geral.md", filler)
        try fixture.write("kb/planos/clinica.md", "# Plano Clínica\n\(fact)\n")
        return ModeEnhancement(sources: [ReferenceSource(url: fixture.url("kb"))])
    }

    func testHaikuSendsSmallDocumentsWhole() async throws {
        try fixture.write("faq.md", fact)
        let response = try await run(request(.anthropic, model: "claude-haiku-5-5"), ModeEnhancement(sources: [ReferenceSource(url: fixture.url("faq.md"))]))
        XCTAssertTrue(response.text.contains("9"))
    }

    func testHaikuSearchesALargeFolder() async throws {
        let response = try await run(request(.anthropic, model: "claude-haiku-5-5"), try largeFolder())
        XCTAssertTrue(response.text.contains("9"))
    }

    func testHaikuSearchesTheWeb() async throws {
        var webRequest = request(.anthropic, model: "claude-haiku-5-5")
        webRequest.system = PromptTemplates.actionSystem(instruction: "Rewrite the message so it states the latest stable Swift version number, looked up on the web.")
        webRequest.user = PromptTemplates.userMessage("a versão mais nova do swift é a ???")
        let response = try await run(webRequest, ModeEnhancement(webSearch: true))
        XCTAssertGreaterThan(response.usage.webSearches ?? 0, 0)
    }

    func testClaudeCodeReadsALargeFolder() async throws {
        let response = try await run(request(.claudeCode, model: "haiku"), try largeFolder())
        XCTAssertTrue(response.text.contains("9"))
    }

    /// A single large file: copied into the run's folder, never granted
    /// through its parent folder.
    func testClaudeCodeReadsALargeSingleFile() async throws {
        let filler = (1...2_500).map { "Linha \($0): política geral sem relação com prazos." }.joined(separator: "\n")
        try fixture.write("manual.md", filler + "\n# Plano Clínica\n\(fact)\n")
        let response = try await run(request(.claudeCode, model: "haiku"), ModeEnhancement(sources: [ReferenceSource(url: fixture.url("manual.md"))]))
        XCTAssertTrue(response.text.contains("9"))
    }

    func testCodexReadsALargeFolder() async throws {
        let response = try await run(request(.codex, model: "default"), try largeFolder())
        XCTAssertTrue(response.text.contains("9"))
    }
}
