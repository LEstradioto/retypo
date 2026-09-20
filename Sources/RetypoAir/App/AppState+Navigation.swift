import Foundation

extension AppState {
    func cycleFooterFocus() {
        if let index = footerFocusIndex {
            let next = index + 1
            footerFocusIndex = next >= footerFocusItemCount ? nil : next
            status = footerFocusIndex == nil ? "Editor" : "Footer focus"
        } else {
            footerFocusIndex = 0
            status = "Footer focus"
        }
    }

    func nextFooterFocus() {
        cycleFooterFocus()
    }

    func previousFooterFocus() {
        if let index = footerFocusIndex {
            let previous = index - 1
            footerFocusIndex = previous < 0 ? nil : previous
            status = footerFocusIndex == nil ? "Editor" : "Footer focus"
        } else {
            footerFocusIndex = footerFocusItemCount - 1
            status = "Footer focus"
        }
    }

    func activateFooterFocus() {
        guard let index = footerFocusIndex, Self.footerActions.indices.contains(index) else { return }
        Self.footerActions[index](self)
    }

    /// Order matches the visual layout in `RetypoView+Footer`: mode,
    /// candidates icon, model, settings, undo, redo, cost.
    private static let footerActions: [(AppState) -> Void] = [
        { $0.activateModeCycle() },
        { $0.toggleCandidateOverlay() },
        { $0.selectAdjacentModel(direction: 1) },
        { $0.requestSettings() },
        { _ = $0.undoEditorChange() },
        { _ = $0.redoEditorChange() },
        { $0.showCostStatus() }
    ]

    private func activateModeCycle() {
        guard let currentIndex = enabledActions.firstIndex(where: { $0.id == currentAction.id }) else { return }
        let next = enabledActions[(currentIndex + 1) % enabledActions.count]
        setCurrentAction(next.id)
    }

    private func showCostStatus() {
        status = "Last \(cost.lastCostLabel) · Session \(cost.sessionCostLabel) · Today \(cost.dayCostLabel)"
    }

    func nextLauncherMode() {
        moveLauncherMode(direction: 1)
    }

    func previousLauncherMode() {
        moveLauncherMode(direction: -1)
    }

    func moveLauncherMode(direction: Int) {
        guard !enabledActions.isEmpty else { return }
        selectedLauncherModeIndex = (selectedLauncherModeIndex + direction + enabledActions.count) % enabledActions.count
        settings.currentActionID = enabledActions[selectedLauncherModeIndex].id
        saveSettings()
    }

    func runSelectedLauncherMode() async {
        guard enabledActions.indices.contains(selectedLauncherModeIndex) else { return }
        let action = enabledActions[selectedLauncherModeIndex]
        setCurrentAction(action.id)
        await runAction(action, source: "candidate")
        // Freeform routes through its own modal flow — don't try to wrap
        // any leftover diff here, that's stale state from a previous run.
        if action.id == EditAction.freeformID { return }
        if !diffText.isEmpty {
            candidateResults = [CandidateResult(action: action, output: outputText, diff: diffText, usage: cost.lastCost.usage, costUSD: cost.lastCost.costUSD)]
            selectedCandidateIndex = 0
            setCandidateOverlayVisible(true)
        }
    }

    func nextCandidate() {
        moveCandidate(direction: 1)
    }

    func previousCandidate() {
        moveCandidate(direction: -1)
    }

    func moveCandidate(direction: Int) {
        guard !candidateResults.isEmpty else { return }
        selectedCandidateIndex = (selectedCandidateIndex + direction + candidateResults.count) % candidateResults.count
        selectCandidate(at: selectedCandidateIndex)
    }

    func selectCandidate(at index: Int) {
        guard candidateResults.indices.contains(index) else { return }
        selectedCandidateIndex = index
        let candidate = candidateResults[index]
        outputText = candidate.output
        diffText = candidate.diff
        ClipboardService.copy(candidate.output)
        status = "Selected \(candidate.action.title)"
    }

    func clearCandidateResults() {
        candidateResults = []
        selectedCandidateIndex = 0
    }

    func restoreSelectedCandidateToEditor() {
        guard candidateResults.indices.contains(selectedCandidateIndex) else { return }
        pushEditorUndoSnapshot()
        inputText = candidateResults[selectedCandidateIndex].output
        draftPersistence.save(inputText)
        setCandidateOverlayVisible(false)
        status = "Applied candidate"
    }

    func selectAdjacentModel(direction: Int) {
        let models = navigableModels
        guard !models.isEmpty else { return }
        let current = selectedModel
        let currentIndex = models.firstIndex { $0.id == current } ?? 0
        let nextIndex = (currentIndex + direction + models.count) % models.count
        setSelectedModel(models[nextIndex].id)
    }
}
