import AppKit
import Carbon

extension AppDelegate {
    func promptViaVSCodeAccessibleView(from application: NSRunningApplication) -> PromptCaptureCandidate? {
        let enabled = state?.settings.experimentalVSCodeAccessibleViewImport ?? true
        let policy = VSCodePromptImportPolicy(enabled: enabled)
        guard policy.shouldTryAccessibleView(bundleIdentifier: application.bundleIdentifier) else {
            logVSCodeAccessibleViewSkip(application)
            return nil
        }
        DebugLog.log("VS Code Accessible View import: sending Option+F2")
        openVSCodeAccessibleView(application)
        defer { closeVSCodeAccessibleView() }
        return waitForVSCodeAccessibleViewPrompt(from: application)
    }

    private func logVSCodeAccessibleViewSkip(_ application: NSRunningApplication) {
        guard VSCodePromptImportPolicy.isVSCodeBundleIdentifier(application.bundleIdentifier) else { return }
        DebugLog.log("VS Code Accessible View import skipped: experimental setting disabled")
    }

    private func openVSCodeAccessibleView(_ application: NSRunningApplication) {
        application.activate(options: [.activateIgnoringOtherApps])
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        postKey(Int(kVK_F2), flags: .maskAlternate)
    }

    private func closeVSCodeAccessibleView() {
        postKey(Int(kVK_Escape), flags: [])
    }

    private func waitForVSCodeAccessibleViewPrompt(from application: NSRunningApplication) -> PromptCaptureCandidate? {
        let deadline = Date().addingTimeInterval(0.8)
        var loggedWindows = false
        while Date() < deadline {
            if let prompt = promptViaVSCodeAccessibleViewWindow(from: application, logWindows: !loggedWindows) {
                return PromptCaptureCandidate(text: prompt.text, kind: .vscodeAccessibleView)
            }
            loggedWindows = true
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return nil
    }

    func postKey(_ keyCode: Int, flags: CGEventFlags) {
        [true, false].forEach { isDown in
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: isDown) else { return }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
