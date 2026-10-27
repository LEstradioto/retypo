import SwiftUI
import AppKit

extension Color {
    /// House accent for custom chrome (links, pills, focus, alerts).
    /// Preset themes bring their own accent; otherwise orange, which holds
    /// contrast on gray in both Light and Dark where blue washed out.
    /// System controls (Toggle, Picker) follow the root `.tint` instead.
    static var retypoAccent: Color { Palette.current.definition?.accent ?? .orange }
}

/// Solid adaptive surfaces. Preset themes resolve to explicit colors;
/// Light / Dark / System resolve through NSColor — no translucency, no
/// opacity hacks. `current` is set from settings at launch and on every
/// theme change (single main window, always on MainActor).
enum Palette {
    static var current: MainTheme = .glass

    static var window: Color { current.definition?.window ?? Color(nsColor: .windowBackgroundColor) }
    static var editor: Color { current.definition?.editor ?? Color(nsColor: .textBackgroundColor) }
    static var card: Color { current.definition?.card ?? Color(nsColor: .controlBackgroundColor) }
    static var hairline: Color { current.definition?.hairline ?? Color(nsColor: .separatorColor) }
    static var primaryText: Color { current.definition?.primaryText ?? Color(nsColor: .labelColor) }
    static var secondaryText: Color { current.definition?.secondaryText ?? Color(nsColor: .secondaryLabelColor) }
    static var tertiaryText: Color { current.definition?.tertiaryText ?? Color(nsColor: .tertiaryLabelColor) }
}

struct PointingCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func pointingCursor() -> some View {
        modifier(PointingCursorModifier())
    }
}

struct SettingsCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.secondaryText)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

struct LabeledShortcutField: View {
    var label: String
    var focusID: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.secondaryText)
            TextField("cmd+opt+]", text: $text)
                .textFieldStyle(.roundedBorder)
                .settingsFocus(focusID, radius: 6)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}

struct SettingsCapsuleButtonStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(active ? Color.white : Palette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(active ? Color.retypoAccent : Palette.card))
            .overlay(Capsule(style: .continuous).strokeBorder(active ? Color.clear : Palette.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SettingsIconButtonStyle: ButtonStyle {
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? Color.red : Palette.primaryText)
            .frame(width: 26, height: 24)
            .background(Circle().fill(destructive ? Color.red.opacity(0.12) : Palette.window))
            .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .pointingCursor()
    }
}

enum HistoryDisplayMode: String, CaseIterable {
    case input
    case output
    case diff

    var title: String {
        switch self {
        case .input: "Input"
        case .output: "Output"
        case .diff: "Diff"
        }
    }

    var next: HistoryDisplayMode {
        switch self {
        case .input: .output
        case .output: .diff
        case .diff: .input
        }
    }

    func text(for entry: HistoryEntry) -> String {
        switch self {
        case .input: entry.input
        case .output: entry.output
        case .diff: entry.diff
        }
    }
}
