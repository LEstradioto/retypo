import AppKit

extension AppDelegate {
    struct ImportSourceContext {
        let application: NSRunningApplication
        let name: String
        let bundleID: String?
        let trustedForAccessibility: Bool
    }

    func importSelectedTextFromFrontmostApp(allowClipboardFallback: Bool) {
        DebugLog.log("import begin nsAppActive=\(NSApp.isActive)")
        guard let source = importSourceContext() else { return }
        showPanel()
        DispatchQueue.main.async { [weak self] in
            self?.continueImportAfterPanelShown(source: source, allowClipboardFallback: allowClipboardFallback)
        }
    }

    private func continueImportAfterPanelShown(source: ImportSourceContext, allowClipboardFallback: Bool) {
        if importImmediateSourceText(source) { return }
        guard allowClipboardFallback else {
            finishImportWithoutClipboardFallback(sourceName: source.name)
            return
        }
        startClipboardPoll(source: source)
    }

    private func importSourceContext() -> ImportSourceContext? {
        guard let application = resolveExternalSource() else { return nil }
        previousApplication = application
        let sourceName = application.localizedName ?? "frontmost app"
        let bundleID = application.bundleIdentifier
        logImportSource(application, sourceName: sourceName, bundleID: bundleID)
        let trusted = requestAccessibilityTrustIfNeeded()
        DebugLog.log("accessibility trusted=\(trusted)")
        return ImportSourceContext(application: application, name: sourceName, bundleID: bundleID, trustedForAccessibility: trusted)
    }

    private func importImmediateSourceText(_ source: ImportSourceContext) -> Bool {
        if source.trustedForAccessibility,
           importViaAXSelectedText(application: source.application, sourceName: source.name) { return true }
        return importVisibleTerminalPrompt(application: source.application, sourceName: source.name)
    }

    private func logImportSource(_ application: NSRunningApplication, sourceName: String, bundleID: String?) {
        DebugLog.log("import source name=\(sourceName) bundle=\(bundleID ?? "nil") pid=\(application.processIdentifier)")
    }

    private func finishImportWithoutClipboardFallback(sourceName: String) {
        if importExistingClipboard(sourceName: sourceName) { return }
        showPanel()
        state?.status = "No selected text or prompt imported"
    }

    private func resolveExternalSource() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else {
            DebugLog.log("import failed: no external frontmost app. frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
            showPanel()
            state?.status = "No external app focused"
            return nil
        }
        return app
    }

    private func importViaAXSelectedText(application: NSRunningApplication, sourceName: String) -> Bool {
        guard let selectedText = selectedTextViaAccessibility(from: application),
              !selectedText.trimmingCharacters(in: .newlines).isEmpty else { return false }
        DebugLog.log("import success via AXSelectedText length=\(selectedText.count)")
        let needsConfirmation = state?.receiveExternalImport(selectedText, source: sourceName) ?? false
        showPanel()
        if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
        return true
    }

    func rememberPreviousApplication() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousApplication = current
        }
    }
}
