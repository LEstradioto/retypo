import XCTest
@testable import Retypo

final class EditorEngineTests: XCTestCase {
    private func snapshot(_ text: String) -> EditorSnapshot {
        EditorSnapshot(
            inputText: text,
            correctedText: "",
            outputText: "",
            status: "Ready",
            diffText: "",
            inlineHighlightRanges: [],
            candidateResults: [],
            showCandidateOverlay: false,
            selectedCandidateIndex: 0,
            wordsChangedLast: 0,
            typingStartedAt: nil
        )
    }

    func testEmptyEngineHasNothingToUndoOrRedo() {
        let engine = EditorEngine(limit: 10)
        XCTAssertFalse(engine.canUndo)
        XCTAssertFalse(engine.canRedo)
    }

    func testPushMakesUndoAvailable() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        XCTAssertTrue(engine.canUndo)
        XCTAssertFalse(engine.canRedo)
    }

    func testPushIsIdempotentForDuplicateTopOfStack() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        engine.pushSnapshot(snapshot("a"))
        XCTAssertEqual(engine.undoStack.count, 1)
    }

    func testPushDistinctSnapshotsAccumulates() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        engine.pushSnapshot(snapshot("b"))
        engine.pushSnapshot(snapshot("c"))
        XCTAssertEqual(engine.undoStack.count, 3)
    }

    func testPushBeyondLimitDropsOldestFirst() {
        var engine = EditorEngine(limit: 3)
        for letter in ["a", "b", "c", "d", "e"] {
            engine.pushSnapshot(snapshot(letter))
        }
        XCTAssertEqual(engine.undoStack.map(\.inputText), ["c", "d", "e"])
    }

    func testPushClearsRedoStack() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        _ = engine.undo(current: snapshot("b"))
        XCTAssertTrue(engine.canRedo)
        engine.pushSnapshot(snapshot("c"))
        XCTAssertFalse(engine.canRedo)
    }

    func testUndoOnEmptyReturnsNil() {
        var engine = EditorEngine(limit: 10)
        XCTAssertNil(engine.undo(current: snapshot("x")))
    }

    func testUndoReturnsTopOfStack() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        engine.pushSnapshot(snapshot("b"))
        let restored = engine.undo(current: snapshot("c"))
        XCTAssertEqual(restored?.inputText, "b")
    }

    func testUndoMovesCurrentToRedo() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        _ = engine.undo(current: snapshot("current"))
        XCTAssertEqual(engine.redoStack.last?.inputText, "current")
    }

    func testRedoReversesUndo() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        engine.pushSnapshot(snapshot("b"))
        let undone = engine.undo(current: snapshot("c"))!
        let redone = engine.redo(current: undone)!
        XCTAssertEqual(redone.inputText, "c")
    }

    func testRedoOnEmptyReturnsNil() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        XCTAssertNil(engine.redo(current: snapshot("x")))
    }

    func testDropRedoClearsRedoOnly() {
        var engine = EditorEngine(limit: 10)
        engine.pushSnapshot(snapshot("a"))
        engine.pushSnapshot(snapshot("b"))
        _ = engine.undo(current: snapshot("c"))
        // undoStack: [a]   redoStack: [c]
        XCTAssertTrue(engine.canRedo)
        XCTAssertTrue(engine.canUndo)
        engine.dropRedo()
        XCTAssertFalse(engine.canRedo)
        XCTAssertTrue(engine.canUndo)
    }

    /// Property: every undo can be reversed by a redo. Round-trip preserves state.
    func testUndoRedoRoundTripPreservesEverySnapshot() {
        var engine = EditorEngine(limit: 100)
        let states = (0..<10).map { snapshot("v\($0)") }
        for state in states { engine.pushSnapshot(state) }

        // Undo all the way back to the initial snapshot, then redo all the way forward.
        var current = snapshot("final")
        var undone: [EditorSnapshot] = []
        while let s = engine.undo(current: current) {
            undone.append(s)
            current = s
        }
        XCTAssertEqual(undone.count, states.count)

        var redone: [EditorSnapshot] = []
        while let s = engine.redo(current: current) {
            redone.append(s)
            current = s
        }
        // Redo brings back the same intermediate snapshots, plus 'final' last.
        XCTAssertEqual(redone.first?.inputText, "v1")
        XCTAssertEqual(redone.last?.inputText, "final")
    }

    func testLimitOfOneKeepsOnlyTheLatest() {
        var engine = EditorEngine(limit: 1)
        engine.pushSnapshot(snapshot("a"))
        engine.pushSnapshot(snapshot("b"))
        engine.pushSnapshot(snapshot("c"))
        XCTAssertEqual(engine.undoStack.map(\.inputText), ["c"])
    }
}
