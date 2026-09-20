import SwiftUI

/// Compact confirmation alert for an incoming external text import.
/// Single row with an accent bar on the left edge so it reads as an
/// alert, not a second editor window.
struct ImportConfirmWindowView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(colors: [Color.white.opacity(0.13), Color.black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }

    private var content: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.accentColor.opacity(0.9))
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 10)
            VStack(alignment: .leading, spacing: 1) {
                Text("Paste into Retypo?")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(summary)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, 10)
            Spacer(minLength: 8)
            Button("Cancel") { state.cancelPendingImport() }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .pointingCursor()
            Button("Paste") { state.confirmPendingImport() }
                .buttonStyle(SettingsCapsuleButtonStyle(active: true))
                .pointingCursor()
        }
        .padding(.trailing, 12)
        .padding(.vertical, 8)
    }

    private var summary: String {
        guard let pending = state.pendingImport else { return "No pending selection" }
        let preview = ImportPreview.truncatedFirstVisibleLine(pending.text)
        return "\(pending.source) · \(pending.text.count)c · \(preview)"
    }
}
