import AppKit

final class KeyHandlingTextView: NSTextView {
    private static var killRing: String = ""
    var onSubmit: (() -> Void)?
    var onRunAll: (() -> Void)?
    var onCancel: (() -> Void)?
    var onTab: (() -> Bool)?
    var onShiftTab: (() -> Bool)?
    var onFocusCycle: (() -> Void)?
    var onEnterInOverlay: (() -> Bool)?
    var onToggleOverlay: (() -> Void)?
    var onSettings: (() -> Void)?
    var onUndo: (() -> Bool)?
    var onRedo: (() -> Bool)?
    var onShortcut: ((String) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if isQuit(event) { NSApp.terminate(nil); return }
        if handleClipboardAndUndo(event) { return }
        if handleControlLineEditing(event) { return }
        if handleOptionArrow(event) { return }
        if isSelectAll(event) { selectAll(nil); return }
        if handleHomeEnd(event) { return }
        if handleSpecialKeys(event) { return }
        if let shortcut = ShortcutFormatter.string(from: event), onShortcut?(shortcut) == true {
            return
        }
        super.keyDown(with: event)
    }

    private func handleSpecialKeys(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 48: return handleTab(event)
        case 2 where event.modifierFlags.contains(.command): onToggleOverlay?(); return true
        case 1 where event.modifierFlags.contains(.command): onSettings?(); return true
        case 36, 76: handleReturn(event); return true
        case 53: onCancel?(); return true
        default: return false
        }
    }

    private func handleTab(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.control) { onFocusCycle?(); return true }
        if event.modifierFlags.contains(.shift), onShiftTab?() == true { return true }
        if onTab?() == true { return true }
        return false
    }

    private func handleReturn(_ event: NSEvent) {
        if event.modifierFlags.contains(.command), event.modifierFlags.contains(.shift) {
            onRunAll?()
        } else if onEnterInOverlay?() == true {
            return
        } else if event.modifierFlags.contains(.shift) {
            insertNewlineIgnoringFieldEditor(nil)
        } else {
            onSubmit?()
        }
    }

    private func handleClipboardAndUndo(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        switch Int(event.keyCode) {
        case 8: copy(nil); return true
        // Cmd+Shift+V is smart-paste, not paste: let it fall through to
        // the shortcut handler instead of inserting clipboard text here.
        case 9 where event.modifierFlags.contains(.shift): return false
        case 9: paste(nil); return true
        case 7: cut(nil); return true
        case 6: performUndoRedo(redo: event.modifierFlags.contains(.shift)); return true
        case 16: performUndoRedo(redo: true); return true
        default: return false
        }
    }

    private func performUndoRedo(redo: Bool) {
        if redo {
            if undoManager?.canRedo == true { undoManager?.redo() } else { _ = onRedo?() }
        } else {
            if undoManager?.canUndo == true { undoManager?.undo() } else { _ = onUndo?() }
        }
    }

    /// The Edit menu sends `undo:` / `redo:` before `keyDown` sees Cmd+Z, and
    /// `NSTextView` does not implement them (the window would). Taking them
    /// here keeps the fallback to the app-level history of mode results.
    @objc func undo(_ sender: Any?) { performUndoRedo(redo: false) }
    @objc func redo(_ sender: Any?) { performUndoRedo(redo: true) }

    /// Always enabled: an empty text undo stack may still have app history.
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        if action == ApplicationMenu.undoAction || action == ApplicationMenu.redoAction { return true }
        return super.validateMenuItem(menuItem)
    }

    private func isQuit(_ event: NSEvent) -> Bool {
        event.keyCode == 12 && event.modifierFlags.contains(.command) // Q
    }

    private func handleControlLineEditing(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.control), !event.modifierFlags.contains(.command) else { return false }
        switch Int(event.keyCode) {
        case 32: deleteFromCaret(toBeginningOfLine: true); return true   // U
        case 40: deleteFromCaret(toBeginningOfLine: false); return true  // K
        case 16: yankKillRing(); return true                              // Y
        default: return false
        }
    }

    private func handleOptionArrow(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.option) else { return false }
        let withShift = event.modifierFlags.contains(.shift)
        switch Int(event.keyCode) {
        case 123: withShift ? moveWordLeftAndModifySelection(nil) : moveWordLeft(nil); return true
        case 124: withShift ? moveWordRightAndModifySelection(nil) : moveWordRight(nil); return true
        default: return false
        }
    }

    private func deleteFromCaret(toBeginningOfLine: Bool) {
        let selection = selectedRange()
        if selection.length > 0 {
            KeyHandlingTextView.killRing = (string as NSString).substring(with: selection)
            textStorage?.replaceCharacters(in: selection, with: "")
            didChangeText()
            return
        }
        let ns = string as NSString
        let location = min(selection.location, ns.length)
        let line = ns.lineRange(for: NSRange(location: location, length: 0))
        let range = toBeginningOfLine
            ? NSRange(location: line.location, length: max(0, location - line.location))
            : forwardDeleteRange(from: location, line: line, in: ns)
        guard range.length > 0 else { return }
        KeyHandlingTextView.killRing = ns.substring(with: range)
        textStorage?.replaceCharacters(in: range, with: "")
        setSelectedRange(NSRange(location: range.location, length: 0))
        didChangeText()
    }

    private func forwardDeleteRange(from location: Int, line: NSRange, in ns: NSString) -> NSRange {
        let lineEnd = max(line.location, line.location + line.length)
        let newlineAdjustedEnd: Int
        if lineEnd > line.location, lineEnd <= ns.length {
            let lastChar = ns.substring(with: NSRange(location: lineEnd - 1, length: 1))
            newlineAdjustedEnd = (lastChar == "\n" || lastChar == "\r") ? lineEnd - 1 : lineEnd
        } else {
            newlineAdjustedEnd = lineEnd
        }
        return NSRange(location: location, length: max(0, newlineAdjustedEnd - location))
    }

    private func yankKillRing() {
        guard !KeyHandlingTextView.killRing.isEmpty else { return }
        insertText(KeyHandlingTextView.killRing, replacementRange: selectedRange())
    }

    private func isSelectAll(_ event: NSEvent) -> Bool {
        guard event.keyCode == 0 else { return false } // A
        return event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
    }

    private func handleHomeEnd(_ event: NSEvent) -> Bool {
        let toDocumentBoundary = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
        switch Int(event.keyCode) {
        case 115: toDocumentBoundary ? moveToBeginningOfDocument(nil) : moveToBeginningOfLine(nil); return true
        case 119: toDocumentBoundary ? moveToEndOfDocument(nil) : moveToEndOfLine(nil); return true
        default: return false
        }
    }
}
