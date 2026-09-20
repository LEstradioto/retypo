import SwiftUI
import AppKit

extension Color {
    /// House accent for custom chrome (links, pills, focus, alerts).
    /// Orange holds contrast on gray in both Light and Dark, where the
    /// system blue washed out. System controls (Toggle, Picker) keep the
    /// macOS default.
    static var retypoAccent: Color { .orange }
}

struct VisualEffectView: NSViewRepresentable {    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
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
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.13)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.retypoAccent.opacity(0.055), radius: 24, x: 0, y: 14)
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
                .foregroundStyle(.secondary)
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
            .foregroundStyle(active ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(active ? Color.retypoAccent.opacity(configuration.isPressed ? 0.68 : 0.84) : Color.white.opacity(configuration.isPressed ? 0.12 : 0.08)))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.13), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SettingsIconButtonStyle: ButtonStyle {
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? Color.red.opacity(0.85) : Color.primary.opacity(0.80))
            .frame(width: 26, height: 24)
            .background(Circle().fill((destructive ? Color.red : Color.retypoAccent).opacity(configuration.isPressed ? 0.18 : 0.09)))
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
