import XCTest
@testable import Retypo

final class VSCodePromptImportPolicyTests: XCTestCase {
    func testRecognizesVSCodeBundleIdentifiers() {
        XCTAssertTrue(VSCodePromptImportPolicy.isVSCodeBundleIdentifier("com.microsoft.VSCode"))
        XCTAssertTrue(VSCodePromptImportPolicy.isVSCodeBundleIdentifier("com.microsoft.VSCodeInsiders"))
        XCTAssertTrue(VSCodePromptImportPolicy.isVSCodeBundleIdentifier("com.visualstudio.code.oss"))
        XCTAssertTrue(VSCodePromptImportPolicy.isVSCodeBundleIdentifier("com.vscodium"))
    }

    func testRejectsNonVSCodeBundleIdentifiers() {
        XCTAssertFalse(VSCodePromptImportPolicy.isVSCodeBundleIdentifier("com.mitchellh.ghostty"))
        XCTAssertFalse(VSCodePromptImportPolicy.isVSCodeBundleIdentifier(nil))
    }

    func testAccessibleViewRequiresOptIn() {
        XCTAssertFalse(VSCodePromptImportPolicy(enabled: false).shouldTryAccessibleView(bundleIdentifier: "com.microsoft.VSCode"))
        XCTAssertTrue(VSCodePromptImportPolicy(enabled: true).shouldTryAccessibleView(bundleIdentifier: "com.microsoft.VSCode"))
    }
}
