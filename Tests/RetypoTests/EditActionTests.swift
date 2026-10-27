import XCTest
@testable import Retypo

final class EditActionTests: XCTestCase {
    func testDefaultsContainCorrectAction() {
        XCTAssertEqual(EditAction.defaults.first?.id, "correct")
    }

    func testDefaultsAllEnabled() {
        XCTAssertTrue(EditAction.defaults.allSatisfy(\.isEnabled))
    }

    func testDefaultsHaveUniqueIDs() {
        let ids = EditAction.defaults.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testCodableRoundTrip() throws {
        let original = EditAction(id: "x", title: "X", instruction: "do x", isEnabled: false)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditAction.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testCustomizedDefaultDetectsInstructionChanges() {
        var action = EditAction.defaults[0]
        XCTAssertFalse(action.hasCustomizedDefault)
        action.instruction = "Use my correction rules."
        XCTAssertTrue(action.hasCustomizedDefault)
    }

    func testResetToDefaultRestoresFieldsAndPreservesEnabledState() {
        var action = EditAction(id: "correct", title: "Mine", instruction: "Custom", isEnabled: false)
        XCTAssertTrue(action.resetToDefault())
        XCTAssertEqual(action.title, "Correct")
        XCTAssertEqual(action.instruction, EditAction.defaults[0].instruction)
        XCTAssertFalse(action.isEnabled)
    }

    func testCustomModeHasNoDefaultToReset() {
        var action = EditAction(id: "mine", title: "Mine", instruction: "Custom")
        XCTAssertFalse(action.hasCustomizedDefault)
        XCTAssertFalse(action.resetToDefault())
        XCTAssertEqual(action.instruction, "Custom")
    }
}
