import XCTest
@testable import RetypoAir

final class ProviderKindTests: XCTestCase {
    func testAllCasesIncludeEveryProvider() {
        XCTAssertEqual(ProviderKind.allCases.count, 6)
        XCTAssertTrue(ProviderKind.allCases.contains(.groq))
        XCTAssertTrue(ProviderKind.allCases.contains(.anthropic))
        XCTAssertTrue(ProviderKind.allCases.contains(.openai))
        XCTAssertTrue(ProviderKind.allCases.contains(.openrouter))
        XCTAssertTrue(ProviderKind.allCases.contains(.claudeCode))
        XCTAssertTrue(ProviderKind.allCases.contains(.codex))
    }

    func testDisplayNames() {
        XCTAssertEqual(ProviderKind.groq.displayName, "Groq")
        XCTAssertEqual(ProviderKind.anthropic.displayName, "Anthropic")
        XCTAssertEqual(ProviderKind.openai.displayName, "OpenAI")
        XCTAssertEqual(ProviderKind.openrouter.displayName, "OpenRouter")
        XCTAssertEqual(ProviderKind.claudeCode.displayName, "Claude Code")
        XCTAssertEqual(ProviderKind.codex.displayName, "Codex")
    }

    func testApiKeyEnvironmentNames() {
        XCTAssertEqual(ProviderKind.groq.apiKeyEnvironmentName, "GROQ_API_KEY")
        XCTAssertEqual(ProviderKind.anthropic.apiKeyEnvironmentName, "ANTHROPIC_API_KEY")
        XCTAssertEqual(ProviderKind.openai.apiKeyEnvironmentName, "OPENAI_API_KEY")
        XCTAssertEqual(ProviderKind.openrouter.apiKeyEnvironmentName, "OPENROUTER_API_KEY")
    }

    /// The CLI providers sign in through `claude` / `codex`, so there is no
    /// key to look for — and no "Missing …_API_KEY" failure to hit.
    func testCLIProvidersHaveNoAPIKeyEnvironmentName() {
        XCTAssertNil(ProviderKind.claudeCode.apiKeyEnvironmentName)
        XCTAssertNil(ProviderKind.codex.apiKeyEnvironmentName)
        XCTAssertTrue(ProviderKind.claudeCode.usesLocalCLI)
        XCTAssertTrue(ProviderKind.codex.usesLocalCLI)
        for provider in [ProviderKind.groq, .anthropic, .openai, .openrouter] {
            XCTAssertFalse(provider.usesLocalCLI, provider.rawValue)
        }
    }

    func testRawValueAndIDMatch() {
        for provider in ProviderKind.allCases {
            XCTAssertEqual(provider.id, provider.rawValue)
        }
    }
}
