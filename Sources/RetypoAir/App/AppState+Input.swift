import Foundation

extension AppState {
    @discardableResult
    func receiveExternalImport(_ text: String, source: String) -> Bool {
        let trimmedIncoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty, !text.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_") else {
            status = "No selected text imported"
            return false
        }

        pendingImport = PendingImport(text: text, source: source)
        status = "Confirm import from \(source)"
        return true
    }

    func confirmPendingImport() {
        guard let pendingImport else { return }
        let text = pendingImport.text
        let source = pendingImport.source
        self.pendingImport = nil
        host?.setImportConfirmationVisible(false)
        importExternalText(text, source: source)
    }

    func cancelPendingImport() {
        pendingImport = nil
        host?.setImportConfirmationVisible(false)
        status = "Import cancelled"
    }

    func importExternalText(_ text: String, source: String) {
        pushEditorUndoSnapshot()
        inputText = text
        outputText = ""
        correctedText = ""
        diffText = ""
        inlineHighlightRanges = []
        candidateResults = []
        showCandidateOverlay = false
        selectedCandidateIndex = 0
        footerFocusIndex = nil
        wordsChangedLast = 0
        typingStartedAt = Date()
        draftPersistence.save(inputText)
        status = "Imported text from \(source)"
    }

    func onInputChanged() {
        commitNonRedoEdit()
        if typingStartedAt == nil { typingStartedAt = Date() }
        updateTypingStats()
        draftPersistence.save(inputText)
        scheduleDraftSnapshot()
        inlineHighlightRanges = []
        if suppressNextInputChange {
            suppressNextInputChange = false
        }
    }

    private func commitNonRedoEdit() {
        if !suppressNextInputChange, editor.canRedo {
            editor.dropRedo()
            publishUndoRedoAvailability()
        }
    }

    func refreshModelsIfPossible() async {
        await refreshModels(for: settings.provider)
    }

    func refreshModels(for provider: ProviderKind) async {
        llm.isLoadingModels = true
        clearLastError()
        status = "Loading \(provider.displayName) models"
        do {
            let models = try await llm.router.listModels(for: provider)
            llm.modelsByProvider[provider] = models
            mergePricingDefaults(for: provider, models: models)
            status = models.isEmpty ? "No models returned" : "Loaded \(models.count) models"
        } catch {
            report(error, while: "Refresh models")
        }
        llm.isLoadingModels = false
    }
}
