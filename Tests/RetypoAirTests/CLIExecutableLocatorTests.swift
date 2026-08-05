import XCTest
@testable import RetypoAir

final class CLIExecutableLocatorTests: XCTestCase {
    func testFindsAnExecutableInTheGivenDirectories() {
        let found = CLIExecutableLocator.find("env", searchPaths: ["/nonexistent", "/usr/bin"])
        XCTAssertEqual(found?.path, "/usr/bin/env")
    }

    func testReturnsNilWhenTheToolIsNotInstalled() {
        XCTAssertNil(CLIExecutableLocator.find("retypo-not-a-real-tool", searchPaths: ["/usr/bin", "/bin"]))
    }

    func testSkipsDirectoriesThatDoNotExist() {
        XCTAssertNil(CLIExecutableLocator.find("env", searchPaths: ["/nonexistent"]))
    }

    /// A GUI app inherits `/usr/bin:/bin:/usr/sbin:/sbin`, so the Homebrew and
    /// per-user install directories have to be searched explicitly.
    func testDefaultSearchPathsCoverTheUsualInstallLocations() {
        let paths = CLIExecutableLocator.defaultSearchPaths
        XCTAssertTrue(paths.contains("/opt/homebrew/bin"))
        XCTAssertTrue(paths.contains("/usr/local/bin"))
        XCTAssertTrue(paths.contains("\(NSHomeDirectory())/.local/bin"))
    }
}

final class CLIModelCatalogTests: XCTestCase {
    func testDefaultSelectionMeansNoModelFlag() {
        XCTAssertNil(CLIModelCatalog.explicitModel("default"))
        XCTAssertNil(CLIModelCatalog.explicitModel("  "))
    }

    func testExplicitSelectionIsTrimmedAndKept() {
        XCTAssertEqual(CLIModelCatalog.explicitModel(" haiku "), "haiku")
    }

    func testBothCatalogsOfferTheConfiguredDefaultFirst() {
        XCTAssertEqual(CLIModelCatalog.claudeCode.first?.id, "default")
        XCTAssertEqual(CLIModelCatalog.codex.first?.id, "default")
    }

    /// A ChatGPT account rejects plain API ids such as `gpt-5.2`.
    func testCodexCatalogOnlyListsCodexEnabledModels() {
        XCTAssertFalse(CLIModelCatalog.codex.contains { $0.id == "gpt-5.2" })
        XCTAssertTrue(CLIModelCatalog.codex.contains { $0.id == "gpt-5.6-sol" })
    }
}
