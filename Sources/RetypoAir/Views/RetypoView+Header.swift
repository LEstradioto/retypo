import AppKit
import SwiftUI

/// The main window header: current mode state (moved from the footer) plus
/// a minimal smart-paste indicator. Cmd+D expands it into the mode picker —
/// mode pills with arrow/enter selection and add/edit/delete/shortcut.
extension RetypoView {
    var headerStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                modeCapsule
                Spacer(minLength: 6)
                smartPasteDot
            }
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.top, 7)
            .padding(.bottom, 5)
            if state.headerModePickerVisible {
                HeaderModePicker()
            }
        }
    }

    private var modeCapsule: some View {
        Button { state.toggleModePicker() } label: {
            HStack(spacing: 5) {
                footerLink(state.currentAction.title, active: true, focused: state.headerModePickerVisible)
                Text(modeShortcutLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .help("Mode (Cmd+D to choose)")
        .pointingCursor()
    }

    private var modeShortcutLabel: String {
        let shortcut = state.settings.shortcutByAction[state.currentAction.id] ?? ""
        return shortcut.isEmpty ? "⌘D" : "\(shortcut) · ⌘D"
    }

    @ViewBuilder
    private var smartPasteDot: some View {
        if state.settings.smartPasteEnabled, state.clipboardHasText {
            Button { state.doSmartPaste() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clipboard.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(state.settings.smartPasteShortcut.isEmpty ? "paste" : state.settings.smartPasteShortcut)
                }
                .foregroundStyle(Color.accentColor.opacity(0.98))
            }
            .buttonStyle(.plain)
            .help("Smart paste: import clipboard")
            .pointingCursor()
        }
    }
}

enum ModeStripFocus {
    static func claim() {
        guard let window = NSApp.keyWindow,
              let catcher = window.contentView?.firstSubview(of: StripKeyCatcher.self) else { return }
        window.makeFirstResponder(catcher)
    }

    static func releaseToEditor() {
        guard let window = NSApp.keyWindow,
              let editor = window.contentView?.firstSubview(of: KeyHandlingTextView.self) else { return }
        window.makeFirstResponder(editor)
    }
}

final class StripKeyCatcher: NSView {
    var onLeft: () -> Void = {}
    var onRight: () -> Void = {}
    var onEnter: () -> Void = {}
    var onEscape: () -> Void = {}

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 123: onLeft()
        case 124: onRight()
        case 36, 76: onEnter()
        case 53: onEscape()
        case 2 where event.modifierFlags.contains(.command): onEscape()
        default: super.keyDown(with: event)
        }
    }
}

struct ModeStripKeyView: NSViewRepresentable {
    var onLeft: () -> Void
    var onRight: () -> Void
    var onEnter: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> StripKeyCatcher {
        StripKeyCatcher()
    }

    func updateNSView(_ catcher: StripKeyCatcher, context: Context) {
        catcher.onLeft = onLeft
        catcher.onRight = onRight
        catcher.onEnter = onEnter
        catcher.onEscape = onEscape
    }
}
