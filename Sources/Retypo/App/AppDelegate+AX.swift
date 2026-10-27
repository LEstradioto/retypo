import AppKit
import ApplicationServices

extension AppDelegate {
    func requestAccessibilityTrustIfNeeded() -> Bool {
        let before = AXIsProcessTrusted()
        DebugLog.log("accessibility trusted before prompt=\(before)")
        if before { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let after = AXIsProcessTrustedWithOptions(options)
        DebugLog.log("accessibility trusted after prompt call=\(after)")
        return after
    }

    func selectedTextViaAccessibility(from application: NSRunningApplication) -> String? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let focused = axAttribute(appElement, kAXFocusedUIElementAttribute) as AXUIElement? else {
            DebugLog.log("AXSelectedText failed: no focused UI element")
            return nil
        }
        if let selected = axAttribute(focused, kAXSelectedTextAttribute) as String?,
           !selected.isEmpty {
            return selected
        }
        DebugLog.log("AXSelectedText empty or unavailable")
        return nil
    }

    func pressCopyMenuItem(in application: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let menuBar = axAttribute(appElement, kAXMenuBarAttribute) as AXUIElement? else {
            DebugLog.log("AX menu bar unavailable")
            return false
        }
        if let exact = findMenuItem(in: menuBar, titleMatches: ["Copy", "Copiar"], maxDepth: 6),
           isAXEnabled(exact) {
            let result = AXUIElementPerformAction(exact, kAXPressAction as CFString)
            DebugLog.log("AX press Copy title result=\(result.rawValue)")
            return result == .success
        }
        if let commandC = findMenuItem(in: menuBar, commandCharacter: "C", maxDepth: 6),
           isAXEnabled(commandC) {
            let result = AXUIElementPerformAction(commandC, kAXPressAction as CFString)
            DebugLog.log("AX press Copy command result=\(result.rawValue)")
            return result == .success
        }
        DebugLog.log("AX copy menu item not found/enabled")
        return false
    }

    private func findMenuItem(in element: AXUIElement, titleMatches titles: Set<String>, maxDepth: Int) -> AXUIElement? {
        guard maxDepth >= 0 else { return nil }
        if let title = axAttribute(element, kAXTitleAttribute) as String?,
           titles.contains(title) {
            return element
        }
        for child in axChildren(of: element) {
            if let found = findMenuItem(in: child, titleMatches: titles, maxDepth: maxDepth - 1) {
                return found
            }
        }
        return nil
    }

    private func findMenuItem(in element: AXUIElement, commandCharacter: String, maxDepth: Int) -> AXUIElement? {
        guard maxDepth >= 0 else { return nil }
        if let command = axAttribute(element, kAXMenuItemCmdCharAttribute) as String?,
           command.caseInsensitiveCompare(commandCharacter) == .orderedSame {
            return element
        }
        for child in axChildren(of: element) {
            if let found = findMenuItem(in: child, commandCharacter: commandCharacter, maxDepth: maxDepth - 1) {
                return found
            }
        }
        return nil
    }

    func axChildren(of element: AXUIElement) -> [AXUIElement] {
        guard let children = axAttribute(element, kAXChildrenAttribute) as [AXUIElement]? else { return [] }
        return children
    }

    private func isAXEnabled(_ element: AXUIElement) -> Bool {
        (axAttribute(element, kAXEnabledAttribute) as Bool?) ?? true
    }

    func axAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return value as? T
    }
}
