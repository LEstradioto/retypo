import AppKit

final class KeyableAuxiliaryPanel: NSPanel {
    var onTabKey: (() -> Void)?
    var onShiftTabKey: (() -> Void)?
    var onLeftKey: (() -> Void)?
    var onRightKey: (() -> Void)?
    var onEnterKey: (() -> Bool)?
    var onCloseKey: (() -> Void)?
    var onCommandSKey: (() -> Void)?
    var onToggleCandidatesKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handlePanelShortcut(event) {
            return
        }
        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        if handlePanelShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handlePanelShortcut(_ event: NSEvent) -> Bool {
        if firstResponder is NSTextView { return handleTextEditingShortcut(event) }
        let mods = event.modifierFlags
        switch Int(event.keyCode) {
        case 48: return invokeTabHandler(shift: mods.contains(.shift))                          // tab
        case 123: return invoke(onLeftKey)                                                       // left arrow
        case 124: return invoke(onRightKey)                                                      // right arrow
        case 13 where mods.contains(.control): return invoke(onCloseKey)                         // ctrl+w
        case 1 where mods.contains(.command): return invoke(onCommandSKey)                       // cmd+s
        case 2 where mods.contains(.command) || mods.contains(.control):
            return invoke(onToggleCandidatesKey)                                                  // cmd/ctrl+d
        case 36, 76: return onEnterKey?() ?? false                                               // enter
        case 53: return invoke(onCloseKey)                                                       // esc
        default: return false
        }
    }

    private func handleTextEditingShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
        if event.keyCode == 2, modifiers.contains(.command) || modifiers.contains(.control) {
            return invoke(onToggleCandidatesKey)
        }
        if event.keyCode == 53 { return invoke(onCloseKey) }
        return false
    }

    private func invokeTabHandler(shift: Bool) -> Bool {
        let handler = shift ? onShiftTabKey : onTabKey
        guard let handler else { return false }
        handler()
        return true
    }

    private func invoke(_ handler: (() -> Void)?) -> Bool {
        guard let handler else { return false }
        handler()
        return true
    }
}
