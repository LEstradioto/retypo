import XCTest
@testable import Retypo

final class RetypoSettingsTests: XCTestCase {
    func testTerminalPromptImportDefaultsToTrue() {
        XCTAssertTrue(RetypoSettings().terminalPromptImportEnabled)
    }

    func testMissingImportSettingsDecodeToEnabledDefaults() throws {
        let settings = try JSONDecoder().decode(RetypoSettings.self, from: Data("{}".utf8))

        XCTAssertTrue(settings.terminalPromptImportEnabled)
        XCTAssertTrue(settings.experimentalVSCodeAccessibleViewImport)
    }

    func testTerminalPromptImportDecodesWhenExplicitlyDisabled() throws {
        let data = Data(#"{"terminalPromptImportEnabled":false}"#.utf8)
        let settings = try JSONDecoder().decode(RetypoSettings.self, from: data)
        XCTAssertFalse(settings.terminalPromptImportEnabled)
    }

    func testExperimentalVSCodeAccessibleViewDefaultsToTrue() {
        XCTAssertTrue(RetypoSettings().experimentalVSCodeAccessibleViewImport)
    }

    func testExperimentalVSCodeAccessibleViewDecodesWhenExplicitlyDisabled() throws {
        let data = Data(#"{"experimentalVSCodeAccessibleViewImport":false}"#.utf8)
        let settings = try JSONDecoder().decode(RetypoSettings.self, from: data)
        XCTAssertFalse(settings.experimentalVSCodeAccessibleViewImport)
    }
}
