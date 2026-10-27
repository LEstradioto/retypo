import AppKit
import ApplicationServices

struct VSCodeAXWindowSnapshot {
    let element: AXUIElement
    let role: String
    let subrole: String
    let titleLength: Int
    let descriptionLength: Int
    let looksAccessible: Bool
}

extension AppDelegate {
    func promptViaVSCodeAccessibleViewWindow(
        from application: NSRunningApplication,
        logWindows: Bool
    ) -> PromptCaptureCandidate? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let windows = preferredVSCodeWindows(in: appElement)
        if logWindows { logVSCodeWindows(windows) }
        return promptFromVSCodeWindows(windows) ?? promptViaVSCodeAccessibilityTree(application) ??
            promptViaVSCodeAccessibleViewClipboard()
    }

    private func promptViaVSCodeAccessibilityTree(_ application: NSRunningApplication) -> PromptCaptureCandidate? {
        promptViaAccessibilityTextBuffer(
            from: application,
            logFailure: false,
            includeApplicationTree: true,
            includeAggregate: true
        )
    }

    private func promptFromVSCodeWindows(_ windows: [VSCodeAXWindowSnapshot]) -> PromptCaptureCandidate? {
        for window in windows {
            if let prompt = promptViaAccessibilityElement(
                window.element,
                label: "VSCodeWindow",
                depth: 10
            ) {
                return prompt
            }
        }
        return nil
    }

    private func preferredVSCodeWindows(in appElement: AXUIElement) -> [VSCodeAXWindowSnapshot] {
        let windows = vscodeWindowSnapshots(in: appElement)
        let accessible = windows.filter(\.looksAccessible)
        return accessible.isEmpty ? windows : accessible
    }

    private func vscodeWindowSnapshots(in appElement: AXUIElement) -> [VSCodeAXWindowSnapshot] {
        prioritizedWindowElements(in: appElement).map(vscodeWindowSnapshot)
    }

    private func prioritizedWindowElements(in appElement: AXUIElement) -> [AXUIElement] {
        var elements: [AXUIElement] = []
        if let focused = axAttribute(appElement, kAXFocusedWindowAttribute) as AXUIElement? { elements.append(focused) }
        elements.append(contentsOf: axAttribute(appElement, kAXWindowsAttribute) as [AXUIElement]? ?? [])
        return elements
    }

    private func vscodeWindowSnapshot(_ element: AXUIElement) -> VSCodeAXWindowSnapshot {
        let title = axAttribute(element, kAXTitleAttribute) as String? ?? ""
        let description = axAttribute(element, kAXDescriptionAttribute) as String? ?? ""
        let role = axAttribute(element, kAXRoleAttribute) as String? ?? "nil"
        let subrole = axAttribute(element, kAXSubroleAttribute) as String? ?? "nil"
        return VSCodeAXWindowSnapshot(
            element: element,
            role: role,
            subrole: subrole,
            titleLength: title.count,
            descriptionLength: description.count,
            looksAccessible: looksLikeAccessibleView(element, title: title, description: description)
        )
    }
}
