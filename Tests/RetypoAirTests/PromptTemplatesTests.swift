import XCTest
@testable import RetypoAir

final class PromptTemplatesTests: XCTestCase {
    func testCorrectionSystemIncludesCustomizedInstruction() {
        let prompt = PromptTemplates.correctionSystem(instruction: "Use Brazilian Portuguese spelling.")

        XCTAssertTrue(prompt.contains("Instruction:\nUse Brazilian Portuguese spelling."))
    }

    func testCorrectionSystemKeepsMachineReadableResponseContract() {
        let prompt = PromptTemplates.correctionSystem(instruction: "Fix typos.")

        XCTAssertTrue(prompt.contains(#"{"corrected":"...", "changed":true, "confidence":0.0}"#))
    }

    func testCorrectionUserDoesNotOverrideCustomizedInstruction() {
        let prompt = PromptTemplates.correctionUser("Make this clearer.")

        XCTAssertEqual(prompt, "Text to edit:\n\nMake this clearer.")
    }
}
