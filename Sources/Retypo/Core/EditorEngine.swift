import Foundation

/// A complete snapshot of the editor surface — every field whose value matters
/// for undo/redo reachability.
///
/// Used as the unit of state inside `EditorEngine`. Stays as a value type so
/// stacks of snapshots are cheap to push, copy, and compare for equality (the
/// engine elides duplicate pushes).
struct EditorSnapshot: Equatable {
    var inputText: String
    var correctedText: String
    var outputText: String
    var status: String
    var diffText: String
    var inlineChanges: TextDiff
    var candidateResults: [CandidateResult]
    var showCandidateOverlay: Bool
    var selectedCandidateIndex: Int
    var wordsChangedLast: Int
    var typingStartedAt: Date?
}

/// A pure value-type undo/redo engine.
///
/// Holds two stacks of `EditorSnapshot`. Knows nothing about SwiftUI, AppKit,
/// or `@MainActor` — the entire transition logic is testable with no test
/// scaffold. AppState is a thin re-publisher around it.
///
/// Invariants:
/// - `pushSnapshot(s)` is idempotent if `s` equals the top of the undo stack.
/// - `pushSnapshot(_)` always clears the redo stack (a new branch).
/// - `undoStack.count <= limit` after every mutation; oldest snapshots are
///   dropped first when the cap is hit.
/// - `undo(current:)` and `redo(current:)` return `nil` when their stack is
///   empty and never throw.
struct EditorEngine: Equatable {
    let limit: Int
    private(set) var undoStack: [EditorSnapshot] = []
    private(set) var redoStack: [EditorSnapshot] = []

    init(limit: Int) {
        precondition(limit >= 1, "EditorEngine limit must be ≥ 1")
        self.limit = limit
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Push the *current* state onto the undo stack so the next mutation is
    /// reversible. Idempotent against the top of the stack. Clears redo.
    mutating func pushSnapshot(_ state: EditorSnapshot) {
        guard undoStack.last != state else { return }
        undoStack.append(state)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
    }

    /// Pop one snapshot from undo and shuttle `current` onto redo. Returns
    /// the snapshot to restore, or nil if undo stack is empty.
    mutating func undo(current: EditorSnapshot) -> EditorSnapshot? {
        guard let snapshot = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return snapshot
    }

    /// Pop one snapshot from redo and shuttle `current` onto undo. Returns
    /// the snapshot to restore, or nil if redo stack is empty.
    mutating func redo(current: EditorSnapshot) -> EditorSnapshot? {
        guard let snapshot = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return snapshot
    }

    /// Drop the redo stack. Called when input changes outside of an explicit
    /// redo — that branch is gone.
    mutating func dropRedo() {
        redoStack.removeAll()
    }
}
