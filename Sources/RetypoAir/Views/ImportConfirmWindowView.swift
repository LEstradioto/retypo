import SwiftUI

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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }

    private var content: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paste into Retypo Air?")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(summary)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Button("Cancel") { state.cancelPendingImport() }
                .buttonStyle(.borderless)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .pointingCursor()
            Button("Paste") { state.confirmPendingImport() }
                .buttonStyle(SettingsCapsuleButtonStyle(active: true))
                .pointingCursor()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var summary: String {
        guard let pending = state.pendingImport else { return "No pending selection" }
        let preview = ImportPreview.truncatedFirstVisibleLine(pending.text)
        return "\(pending.source) · \(pending.text.count)c · \(preview)"
    }
}
