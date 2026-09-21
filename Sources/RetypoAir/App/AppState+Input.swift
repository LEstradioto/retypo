import Foundation

extension AppState {
    /// External text (global hotkey import, terminal prompt) is staged, not
    /// pasted: the header dot lights up and the smart-paste shortcut (or a
    /// click on the dot) writes it into the editor. A conscious decision,
    /// never automatic. With smart paste disabled there is no paste path at
    /// all, so imports go straight into the editor instead of stranding.
    /// Undo (Cmd+Z) still restores after a paste.
    func receiveExternalImport(_ text: String, source: String) {
        let trimmedIncoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty, !text.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_") else {
            status = "No selected text imported"
            return
        }
        guard settings.smartPasteEnabled else {
            importExternalText(text, source: source)
            return
        }
        stagedImport = StagedImport(text: text, source: source)
        status = "Staged from \(source) — \(pasteHint) to paste"
    }

    /// The conscious paste: writes the staged import into the editor and
    /// consumes the stage. Fires only from its shortcut (or the header dot)
    /// while the panel is open. Cmd+V stays native and is untouched.
    func doSmartPaste() {
        guard settings.smartPasteEnabled else { return }
        guard let staged = stagedImport else {
            status = "Nothing staged — grab text with the global shortcut first"
            return
        }
        stagedImport = nil
        importExternalText(staged.text, source: staged.source)
    }

    private var pasteHint: String {
        let shortcut = ShortcutFormatter.normalize(settings.smartPasteShortcut)
        return shortcut.isEmpty ? "paste" : shortcut
    }

    func importExternalText(_ text: String, source: String) {
        pushEditorUndoSnapshot()
        inputText = text
        outputText = ""
        correctedText = ""
        diffText = ""
        inlineHighlightRanges = []
        candidateResults = []
        setCandidateOverlayVisible(false)
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
            status = models.isEmpty ? "No models returned" : "Loaded \(models.count) models\(await fetchedPricingSuffix())"
        } catch {
            report(error, while: "Refresh models")
        }
        llm.isLoadingModels = false
    }

    /// Best-effort models.dev refresh. Offline or malformed responses stay
    /// silent — bundled defaults already cover the readout.
    private func fetchedPricingSuffix() async -> String {
        guard let fetched = try? await ModelsDevPricing.fetchSnapshot() else { return "" }
        let inserted = cost.mergeFetchedPricing(fetched)
        return inserted > 0 ? " · +\(inserted) prices" : ""
    }
}
