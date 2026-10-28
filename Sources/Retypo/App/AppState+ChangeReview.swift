import Foundation

/// The editor's change marks and the track-changes review over it. Both
/// describe one result; any other text in the editor retires them.
extension AppState {
    /// Fixed, like Cmd+D: the mode picker keeps Cmd+D, the review takes the
    /// shifted D. A mode bound to it first still wins (`handleShortcut`).
    static let changeReviewShortcut = "cmd+shift+d"

    /// Marks the editor's text with what a run changed in it.
    func showChanges(_ changes: TextDiff) {
        inlineChanges = changes
        wordsChangedLast = changes.editCount
        isReviewingChanges = false
    }

    /// Called on every editor write: typing, undo, restore or import.
    func dropStaleChanges() {
        guard inlineChanges.hasEdits, inputText != inlineChanges.revised else { return }
        inlineChanges = .none
        isReviewingChanges = false
    }

    func toggleChangeReview() {
        isReviewingChanges = !isReviewingChanges && inlineChanges.hasEdits
    }

    func closeChangeReview() {
        isReviewingChanges = false
    }

    /// Esc leaves the review before it hides the panel.
    func cancelFromEditor() {
        guard isReviewingChanges else { return requestHide() }
        closeChangeReview()
    }
}
