import AppKit
import Foundation

extension AppState {
    /// External text (global hotkey import, terminal prompt, smart paste)
    /// goes straight into the editor — no confirmation modal. Undo (Cmd+Z)
    /// restores whatever was there before.
    func receiveExternalImport(_ text: String, source: String) {
        let trimmedIncoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty, !text.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_") else {
            status = "No selected text imported"
            return
        }
        importExternalText(text, source: source)
    }

    /// Smart paste: pull the system clipboard straight into the editor.
    /// Fires only from its shortcut while the panel is open — no header
    /// alert, no confirmation modal. Skips when the clipboard is empty or
    /// already matches the editor; that's the "smart" part.
    func doSmartPaste() {
        guard settings.smartPasteEnabled else { return }
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            status = "Clipboard is empty"
            return
        }
        guard text != inputText.trimmingCharacters(in: .whitespacesAndNewlines) else {
            status = "Already matches clipboard"
            return
        }
        importExternalText(text, source: "Clipboard")
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
