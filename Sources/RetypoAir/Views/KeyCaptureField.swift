import AppKit
import SwiftUI

/// A shortcut field that captures keys instead of typing them.
///
/// Click to arm ("press keys…"), then the next key combo with ⌘/⌃/⌥ is
/// committed through `commit` (normalized `cmd+shift+v` form). Esc cancels.
/// `commit` returns an error message when the combo is taken — shown inline
/// and the old value kept. Empty shortcut clears via the × button, which
/// also routes through `commit`.
struct KeyCaptureField: View {
    var text: String
    var commit: (String) -> String?

    @State private var capturing = false
    @State private var error: String?
    @State private var monitor: Any?

    var body: some View {
        Button(action: beginCapture) {
            HStack(spacing: 4) {
                Image(systemName: capturing ? "keyboard.badge.ellipsis" : "keyboard")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                if !text.isEmpty, !capturing {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .onTapGesture { _ = commit("") }
                }
            }
            .foregroundStyle(error != nil ? Color.red.opacity(0.9) : .primary.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(capturing ? 0.14 : 0.07)))
            .overlay(Capsule(style: .continuous).strokeBorder(
                error != nil ? Color.red.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .help(error ?? (capturing ? "Press keys, Esc cancels" : "Click to record a shortcut"))
        .onDisappear(perform: endCapture)
    }

    private var label: String {
        if let error { return error }
        if capturing { return "press keys…" }
        return text.isEmpty ? "record" : text
    }

    private func beginCapture() {
        guard !capturing else { return }
        capturing = true
        error = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { cancelCapture(); return nil }
            guard let shortcut = ShortcutFormatter.string(from: event) else {
                error = "Add ⌘, ⌃ or ⌥"
                return nil
            }
            finishCapture(ShortcutFormatter.normalize(shortcut))
            return nil
        }
    }

    private func finishCapture(_ shortcut: String) {
        endCapture()
        error = commit(shortcut)
    }

    private func cancelCapture() {
        endCapture()
        error = nil
    }

    private func endCapture() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capturing = false
    }
}
