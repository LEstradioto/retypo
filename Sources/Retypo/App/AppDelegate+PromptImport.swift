import AppKit

extension AppDelegate {
    func importVisibleTerminalPrompt(application: NSRunningApplication, sourceName: String) -> Bool {
        let terminalImportEnabled = state?.settings.terminalPromptImportEnabled ?? true
        if terminalImportEnabled, let prompt = promptViaAccessibilityTextBuffer(from: application) {
            return importTerminalPrompt(prompt, sourceName: sourceName)
        }
        guard let prompt = promptViaVSCodeAccessibleView(from: application) else { return false }
        return importTerminalPrompt(prompt, sourceName: sourceName)
    }

    private func importTerminalPrompt(_ prompt: PromptCaptureCandidate, sourceName: String) -> Bool {
        DebugLog.log("import success via \(prompt.kind) length=\(prompt.text.count)")
        let source = prompt.kind.sourceName(applicationName: sourceName)
        state?.receiveExternalImport(prompt.text, source: source)
        showPanel()
        return true
    }
}
