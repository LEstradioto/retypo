import ApplicationServices

extension AppDelegate {
    func looksLikeAccessibleView(_ element: AXUIElement, title: String, description: String) -> Bool {
        accessibleTextSignal(title) || accessibleTextSignal(description) ||
            descendantHasAccessibleSignal(element, depth: 5)
    }

    private func descendantHasAccessibleSignal(_ element: AXUIElement, depth: Int) -> Bool {
        guard depth > 0 else { return false }
        return axChildren(of: element).contains { child in
            accessibleTextSignal(axAttribute(child, kAXTitleAttribute) as String? ?? "") ||
                accessibleTextSignal(axAttribute(child, kAXDescriptionAttribute) as String? ?? "") ||
                descendantHasAccessibleSignal(child, depth: depth - 1)
        }
    }

    private func accessibleTextSignal(_ text: String) -> Bool {
        text.lowercased().contains("accessible view")
    }

    func logVSCodeWindows(_ windows: [VSCodeAXWindowSnapshot]) {
        DebugLog.log("VS Code AX windows count=\(windows.count) accessible=\(windows.filter(\.looksAccessible).count)")
        for (index, window) in windows.prefix(5).enumerated() {
            logVSCodeWindow(window, index: index)
        }
    }

    private func logVSCodeWindow(_ window: VSCodeAXWindowSnapshot, index: Int) {
        DebugLog.log("VS Code AX window[\(index)] role=\(window.role) subrole=\(window.subrole) titleLen=\(window.titleLength) descLen=\(window.descriptionLength) accessible=\(window.looksAccessible)")
    }
}
