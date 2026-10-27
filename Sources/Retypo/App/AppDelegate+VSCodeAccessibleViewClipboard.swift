import AppKit
import Carbon

extension AppDelegate {
    func promptViaVSCodeAccessibleViewClipboard() -> PromptCaptureCandidate? {
        let snapshot = ClipboardService.snapshot()
        let marker = primeVSCodeAccessibleViewClipboard()
        postSelectAllAndCopy()
        let copied = copiedVSCodeAccessibleViewText(markerChangeCount: marker.changeCount)
        ClipboardService.restore(snapshot)
        return parsedVSCodeAccessibleViewClipboard(copied, marker: marker.text)
    }

    private func primeVSCodeAccessibleViewClipboard() -> (text: String, changeCount: Int) {
        let pasteboard = NSPasteboard.general
        let marker = "__RETYP_AIR_VSCODE_ACCESSIBLE_VIEW_\(UUID().uuidString)__"
        pasteboard.clearContents()
        pasteboard.setString(marker, forType: .string)
        return (marker, pasteboard.changeCount)
    }

    private func postSelectAllAndCopy() {
        postKey(Int(kVK_ANSI_A), flags: .maskCommand)
        RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        postKey(Int(kVK_ANSI_C), flags: .maskCommand)
    }

    private func copiedVSCodeAccessibleViewText(markerChangeCount: Int) -> String {
        let deadline = Date().addingTimeInterval(0.35)
        while Date() < deadline {
            let pasteboard = NSPasteboard.general
            if pasteboard.changeCount != markerChangeCount { return pasteboard.string(forType: .string) ?? "" }
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        return ""
    }

    private func parsedVSCodeAccessibleViewClipboard(_ text: String, marker: String) -> PromptCaptureCandidate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(marker) else {
            DebugLog.log("VS Code Accessible View clipboard unavailable len=\(text.count)")
            return nil
        }
        DebugLog.log("VS Code Accessible View clipboard len=\(text.count)")
        if let prompt = VSCodeAccessibleViewClipboardParser().prompt(from: text, marker: marker) {
            return prompt
        }
        DebugLog.log("VS Code Accessible View clipboard rejected len=\(text.count)")
        return nil
    }
}
