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
                stagedDot
            }
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.secondaryText)
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
                    .foregroundStyle(Palette.tertiaryText)
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

    /// Lights up only while staged import text waits for a conscious paste.
    /// Click pastes exactly like the smart-paste shortcut.
    @ViewBuilder
    private var stagedDot: some View {
        if state.stagedImport != nil, state.settings.smartPasteEnabled {
            Button { state.doSmartPaste() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clipboard.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(state.settings.smartPasteShortcut.isEmpty ? "paste" : state.settings.smartPasteShortcut)
                }
                .foregroundStyle(Color.retypoAccent)
            }
            .buttonStyle(.plain)
            .help(stagedHelp)
            .pointingCursor()
        }
    }

    private var stagedHelp: String {
        guard let staged = state.stagedImport else { return "Smart paste" }
        let preview = staged.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)
        return "Paste staged text from \(staged.source): \(preview)"
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
        let catcher = StripKeyCatcher()
        // Claim here, not in SwiftUI onAppear: the AppKit view may not be
        // in a window yet when appear fires, so that claim silently misses
        // and arrows never reach the picker.
        DispatchQueue.main.async { [weak catcher] in
            guard let catcher, let window = catcher.window else {
                DebugLog.log("mode picker focus claim failed: catcher has no window")
                return
            }
            DebugLog.log("mode picker focus claimed=\(window.makeFirstResponder(catcher))")
        }
        return catcher
    }

    func updateNSView(_ catcher: StripKeyCatcher, context: Context) {
        catcher.onLeft = onLeft
        catcher.onRight = onRight
        catcher.onEnter = onEnter
        catcher.onEscape = onEscape
    }
}
