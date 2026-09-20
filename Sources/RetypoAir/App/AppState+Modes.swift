import Foundation

extension AppState {
    // Modes CRUD moved out of Settings; the header popover (modes
    // editor) is the caller as of the next slice.
    // periphery:ignore
    func addMode() {
        let action = EditAction(id: UUID().uuidString, title: "New mode", instruction: "Edit the text according to this instruction.", isEnabled: true)
        actions.append(action)
        setCurrentAction(action.id)
        saveModes()
    }

    // periphery:ignore
    func deleteMode(_ action: EditAction) {
        guard actions.count > 1, action.id != EditAction.freeformID else { return }
        actions.removeAll { $0.id == action.id }
        if settings.currentActionID == action.id { settings.currentActionID = enabledActions.first?.id ?? actions.first?.id ?? "correct" }
        saveModes()
        saveSettings()
    }

    func updateMode(_ action: EditAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[index] = action
        saveModes()
    }

    // periphery:ignore
    func toggleModeEnabled(_ actionID: String) {
        guard let index = actions.firstIndex(where: { $0.id == actionID }) else { return }
        actions[index].isEnabled.toggle()
        if !actions[index].isEnabled, settings.currentActionID == actionID {
            settings.currentActionID = enabledActions.first?.id ?? actions[index].id
            saveSettings()
        }
        saveModes()
    }

    func restoreHistory(_ entry: HistoryEntry, useOutput: Bool = false) {
        pushEditorUndoSnapshot()
        inputText = useOutput ? entry.output : entry.input
        outputText = entry.output
        diffText = entry.diff
        settings.provider = entry.provider
        settings.modelByProvider[entry.provider] = entry.model
        settings.currentActionID = entry.actionID
        status = "Restored"
        draftPersistence.save(inputText)
        saveSettings()
    }

    func restoreDraftSnapshot(_ snapshot: DraftSnapshot) {
        inputText = snapshot.text
        draftPersistence.save(inputText)
        status = "Draft restored"
    }

    func isAcceptedModel(_ modelID: String, provider: ProviderKind? = nil) -> Bool {
        let provider = provider ?? settings.provider
        return Set(settings.acceptedModelIDsByProvider[provider] ?? []).contains(modelID)
    }

    func toggleAcceptedModel(_ modelID: String, provider: ProviderKind? = nil) {
        let provider = provider ?? settings.provider
        var values = settings.acceptedModelIDsByProvider[provider] ?? []
        if values.contains(modelID) {
            values.removeAll { $0 == modelID }
        } else {
            values.append(modelID)
        }
        settings.acceptedModelIDsByProvider[provider] = values
        status = values.isEmpty ? "Browsing all models" : "Browsing \(values.count) accepted models"
        saveSettings()
    }
}
