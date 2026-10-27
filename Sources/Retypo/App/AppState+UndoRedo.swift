import Foundation
import AppKit

extension AppState {
    @discardableResult
    func undoEditorChange() -> Bool {
        guard let snapshot = editor.undo(current: currentEditorSnapshot()) else {
            status = "Nothing to undo"
            publishUndoRedoAvailability()
            return false
        }
        restoreEditorSnapshot(snapshot)
        status = "Undone"
        publishUndoRedoAvailability()
        return true
    }

    @discardableResult
    func redoEditorChange() -> Bool {
        guard let snapshot = editor.redo(current: currentEditorSnapshot()) else {
            status = "Nothing to redo"
            publishUndoRedoAvailability()
            return false
        }
        restoreEditorSnapshot(snapshot)
        status = "Redone"
        publishUndoRedoAvailability()
        return true
    }

    func pushEditorUndoSnapshot() {
        editor.pushSnapshot(currentEditorSnapshot())
        publishUndoRedoAvailability()
    }

    func publishUndoRedoAvailability() {
        canUndoEditorChange = editor.canUndo
        canRedoEditorChange = editor.canRedo
    }

    fileprivate func currentEditorSnapshot() -> EditorSnapshot {
        EditorSnapshot(
            inputText: inputText,
            correctedText: correctedText,
            outputText: outputText,
            status: status,
            diffText: diffText,
            inlineHighlightRanges: inlineHighlightRanges,
            candidateResults: candidateResults,
            showCandidateOverlay: showCandidateOverlay,
            selectedCandidateIndex: selectedCandidateIndex,
            wordsChangedLast: wordsChangedLast,
            typingStartedAt: typingStartedAt
        )
    }

    fileprivate func restoreEditorSnapshot(_ snapshot: EditorSnapshot) {
        inputText = snapshot.inputText
        correctedText = snapshot.correctedText
        outputText = snapshot.outputText
        diffText = snapshot.diffText
        inlineHighlightRanges = snapshot.inlineHighlightRanges
        candidateResults = snapshot.candidateResults
        showCandidateOverlay = snapshot.showCandidateOverlay
        selectedCandidateIndex = min(snapshot.selectedCandidateIndex, max(0, candidateResults.count - 1))
        wordsChangedLast = snapshot.wordsChangedLast
        typingStartedAt = snapshot.typingStartedAt ?? Date()
        draftPersistence.save(inputText)
        host?.setCandidatesVisible(showCandidateOverlay)
    }
}
