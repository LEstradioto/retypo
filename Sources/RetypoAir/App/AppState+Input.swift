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
        lastAutoSubmittedHash = nil
        typingStartedAt = Date()
        DraftStore.save(inputText)
        status = "Imported text from \(source)"
    }

    func onInputChanged() {
        commitNonRedoEdit()
        if typingStartedAt == nil { typingStartedAt = Date() }
        updateTypingStats()
        DraftStore.save(inputText)
        scheduleDraftSnapshot()
        inlineHighlightRanges = []
        guard !suppressNextInputChange else {
            suppressNextInputChange = false
            return
        }
        scheduleAutoCorrectIfEligible()
    }

    private func commitNonRedoEdit() {
        if !suppressNextInputChange, editor.canRedo {
            editor.dropRedo()
            publishUndoRedoAvailability()
        }
    }

    /// Flips the preference, and says so when the provider overrides it.
    func toggleAutoRun() {
        settings.autoCorrect.toggle()
        saveSettings()
        guard settings.autoCorrect, settings.provider.usesLocalCLI else { return }
        status = "Auto-run stays off for \(settings.provider.displayName) — press Enter to run"
    }

    private func scheduleAutoCorrectIfEligible() {
        guard autoRunEnabled else { return }
        guard CorrectionPolicy.shouldAutoCorrect(inputText) else { return }
        let hash = inputText.hashValue
        guard hash != lastAutoSubmittedHash else { return }
        debouncer.schedule(milliseconds: settings.debounceMs) { [weak self] in
            guard let self else { return }
            await self.runCurrentAction(source: "auto")
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
