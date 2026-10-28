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

    /// The last run's changes while the editor holds its result. Typing
    /// hides them; undoing back to the result shows them again.
    var visibleChanges: TextDiff {
        inputText == inlineChanges.revised ? inlineChanges : .none
    }

    /// Called on every editor write: anything but the result ends the review.
    func closeReviewIfEdited() {
        guard isReviewingChanges, inputText != inlineChanges.revised else { return }
        isReviewingChanges = false
    }

    func toggleChangeReview() {
        isReviewingChanges = !isReviewingChanges && visibleChanges.hasEdits
    }

    /// Return while reviewing goes back to editing instead of running the
    /// mode again on the result, a paid call nobody asked for.
    func submitFromEditor() async {
        guard !isReviewingChanges else { return closeChangeReview() }
        await runCurrentAction(source: "enter")
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
