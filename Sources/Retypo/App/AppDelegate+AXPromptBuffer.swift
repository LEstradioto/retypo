import AppKit
import ApplicationServices

extension AppDelegate {
    func promptViaAccessibilityTextBuffer(
        from application: NSRunningApplication,
        logFailure: Bool = true,
        includeApplicationTree: Bool = false,
        includeAggregate: Bool = false
    ) -> PromptCaptureCandidate? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let candidates = textCandidates(
            in: appElement,
            includeApplicationTree: includeApplicationTree,
            includeAggregate: includeAggregate
        )
        logTextCandidateSummary(candidates, includeApplicationTree: includeApplicationTree)
        if let prompt = prompt(from: candidates) {
            return prompt
        }
        if logFailure { DebugLog.log("AX text buffer prompt unavailable") }
        return nil
    }

    func promptViaAccessibilityElement(
        _ element: AXUIElement,
        label: String,
        depth: Int
    ) -> PromptCaptureCandidate? {
        let candidates = accessibilityTextCandidates(from: element, depth: depth, includeAggregate: true)
        logElementCandidateSummary(candidates, label: label)
        return prompt(from: candidates)
    }

    private func textCandidates(
        in appElement: AXUIElement,
        includeApplicationTree: Bool,
        includeAggregate: Bool
    ) -> [String] {
        guard let focused = focusedElement(in: appElement) else { return [] }
        let focusedValues = accessibilityTextCandidates(from: focused, depth: 4, includeAggregate: includeAggregate)
        guard includeApplicationTree else { return focusedValues }
        return focusedValues + applicationTreeTextCandidates(from: appElement, includeAggregate: includeAggregate)
    }

    private func focusedElement(in appElement: AXUIElement) -> AXUIElement? {
        guard let focused = axAttribute(appElement, kAXFocusedUIElementAttribute) as AXUIElement? else {
            DebugLog.log("AX text buffer failed: no focused UI element")
            return nil
        }
        return focused
    }

    private func applicationTreeTextCandidates(from appElement: AXUIElement, includeAggregate: Bool) -> [String] {
        let windows = axAttribute(appElement, kAXWindowsAttribute) as [AXUIElement]? ?? []
        return windows.flatMap { accessibilityTextCandidates(from: $0, depth: 8, includeAggregate: includeAggregate) }
    }

    private func accessibilityTextCandidates(
        from element: AXUIElement,
        depth: Int,
        includeAggregate: Bool
    ) -> [String] {
        let values = visibleTextCandidates(from: element) + childTextCandidates(from: element, depth: depth)
        return sortedTextCandidates(values, includeAggregate: includeAggregate)
    }

    private func visibleTextCandidates(from element: AXUIElement) -> [String] {
        [visibleString(for: element), axAttribute(element, kAXValueAttribute) as String?,
         axAttribute(element, kAXTitleAttribute) as String?,
         axAttribute(element, kAXDescriptionAttribute) as String?].compactMap { $0 }
    }

    private func childTextCandidates(from element: AXUIElement, depth: Int) -> [String] {
        guard depth > 0 else { return [] }
        return axChildren(of: element).flatMap { child in
            visibleTextCandidates(from: child) + childTextCandidates(from: child, depth: depth - 1)
        }
    }

    private func prompt(from candidates: [String]) -> PromptCaptureCandidate? {
        let extractor = PromptBufferExtractor()
        for text in candidates {
            if let prompt = extractor.prompt(from: text) {
                DebugLog.log("import success via AX text buffer length=\(prompt.text.count)")
                return prompt
            }
        }
        return nil
    }

    private func sortedTextCandidates(_ values: [String], includeAggregate: Bool) -> [String] {
        let filtered = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let candidates = includeAggregate ? filtered + aggregateCandidate(filtered) : filtered
        return Array(Set(candidates)).sorted { $0.count > $1.count }
    }

    private func aggregateCandidate(_ values: [String]) -> [String] {
        let joined = values.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? [] : [joined]
    }

    private func visibleString(for element: AXUIElement) -> String? {
        guard let range = visibleCharacterRange(for: element) else { return nil }
        return string(for: range, in: element)
    }

    private func visibleCharacterRange(for element: AXUIElement) -> CFRange? {
        guard let value = axAttribute(element, kAXVisibleCharacterRangeAttribute) as AXValue? else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else { return nil }
        return range
    }

    private func string(for range: CFRange, in element: AXUIElement) -> String? {
        var mutableRange = range
        guard let value = AXValueCreate(.cfRange, &mutableRange) else { return nil }
        var output: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, value, &output
        )
        guard result == .success else { return nil }
        return output as? String
    }
}
