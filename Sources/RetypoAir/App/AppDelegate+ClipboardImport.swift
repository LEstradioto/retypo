import AppKit

extension AppDelegate {
    struct ImportPollContext {
        let originalClipboard: ClipboardService.Snapshot
        let markerChangeCount: Int
        let source: ImportSourceContext
        let deadline: Date
    }

    func startClipboardPoll(source: ImportSourceContext) {
        let snapshot = ClipboardService.snapshot()
        let marker = primeClipboardMarker()
        guard source.trustedForAccessibility, pressCopyMenuItem(in: source.application) else {
            finishUnavailableCopyMenu(snapshot: snapshot, source: source)
            return
        }
        DebugLog.log("copy menu pressed via AX")
        showPanel()
        pollPressedCopy(snapshot: snapshot, marker: marker, source: source)
    }

    /// Priority 3 fallback: import whatever the user already has on the
    /// system clipboard. Returns true if anything was imported.
    func importExistingClipboard(sourceName: String) -> Bool {
        let snapshot = ClipboardService.snapshot()
        guard let text = snapshot.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return false
        }
        DebugLog.log("import fallback: using existing clipboard length=\(text.count)")
        state?.receiveExternalImport(text, source: "\(sourceName) (clipboard)")
        showPanel()
        return true
    }

    private func primeClipboardMarker() -> (text: String, changeCount: Int) {
        let pasteboard = NSPasteboard.general
        let marker = "__RETYP_AIR_IMPORT_EMPTY_\(UUID().uuidString)__"
        pasteboard.clearContents()
        pasteboard.setString(marker, forType: .string)
        return (marker, pasteboard.changeCount)
    }

    private func pollPressedCopy(
        snapshot: ClipboardService.Snapshot,
        marker: (text: String, changeCount: Int),
        source: ImportSourceContext
    ) {
        completeSelectionImportWhenClipboardChanges(ImportPollContext(
            originalClipboard: snapshot,
            markerChangeCount: marker.changeCount,
            source: source,
            deadline: Date().addingTimeInterval(0.4)
        ))
    }

    private func finishUnavailableCopyMenu(snapshot: ClipboardService.Snapshot, source: ImportSourceContext) {
        DebugLog.log("copy menu unavailable; not sending synthetic cmd+c to avoid leaking literal c")
        ClipboardService.restore(snapshot)
        showPanel()
        state?.status = unavailableCopyMenuStatus(source)
    }

    private func completeSelectionImportWhenClipboardChanges(_ ctx: ImportPollContext) {
        let imported = NSPasteboard.general.string(forType: .string) ?? ""
        let changed = clipboardChanged(imported: imported, markerChangeCount: ctx.markerChangeCount)
        DebugLog.log("clipboard poll changed=\(changed) changeCount=\(NSPasteboard.general.changeCount) markerChangeCount=\(ctx.markerChangeCount) importedLen=\(imported.count)")
        if !changed, Date() < ctx.deadline {
            scheduleClipboardPoll(ctx)
            return
        }
        ClipboardService.restore(ctx.originalClipboard)
        if importChangedClipboardValue(imported, changed: changed, source: ctx.source) { return }
        failImport(ctx: ctx)
    }

    private func clipboardChanged(imported: String, markerChangeCount: Int) -> Bool {
        NSPasteboard.general.changeCount != markerChangeCount ||
            !imported.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_")
    }

    private func importChangedClipboardValue(_ imported: String, changed: Bool, source: ImportSourceContext) -> Bool {
        let text = imported.trimmingCharacters(in: .newlines)
        guard changed, !text.isEmpty, !imported.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_") else { return false }
        DebugLog.log("import success via clipboard length=\(imported.count)")
        state?.receiveExternalImport(imported, source: source.name)
        showPanel()
        return true
    }

    private func scheduleClipboardPoll(_ ctx: ImportPollContext) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.completeSelectionImportWhenClipboardChanges(ctx)
        }
    }

    private func failImport(ctx: ImportPollContext) {
        DebugLog.log("import failed: clipboard did not contain selected text")
        if importOriginalClipboard(ctx) { return }
        showPanel()
        state?.status = "No selected text or prompt imported.\(terminalDisabledHint(ctx.source))\(vscodeDisabledHint(ctx.source))\(accessibilityHint(ctx.source))"
    }

    private func importOriginalClipboard(_ ctx: ImportPollContext) -> Bool {
        guard let original = ctx.originalClipboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !original.isEmpty else { return false }
        DebugLog.log("import fallback: using original clipboard length=\(original.count)")
        let source = "\(ctx.source.name) (clipboard)"
        state?.receiveExternalImport(original, source: source)
        showPanel()
        return true
    }

    private func unavailableCopyMenuStatus(_ source: ImportSourceContext) -> String {
        guard source.trustedForAccessibility else { return "Grant Accessibility permission to import selection" }
        return "No selected text or prompt imported.\(terminalDisabledHint(source))\(vscodeDisabledHint(source))"
    }

    private func accessibilityHint(_ source: ImportSourceContext) -> String {
        source.trustedForAccessibility ? "" : " Grant Accessibility permission to Retypo Air, then try again."
    }

    private func vscodeDisabledHint(_ source: ImportSourceContext) -> String {
        let enabled = state?.settings.experimentalVSCodeAccessibleViewImport ?? true
        let policy = VSCodePromptImportPolicy(enabled: enabled)
        guard !policy.shouldTryAccessibleView(bundleIdentifier: source.bundleID),
              VSCodePromptImportPolicy.isVSCodeBundleIdentifier(source.bundleID) else { return "" }
        return VSCodePromptImportPolicy.disabledHint
    }

    private func terminalDisabledHint(_ source: ImportSourceContext) -> String {
        let enabled = state?.settings.terminalPromptImportEnabled ?? true
        guard !enabled, !VSCodePromptImportPolicy.isVSCodeBundleIdentifier(source.bundleID) else { return "" }
        return " Terminal prompt import is disabled in Settings."
    }
}
