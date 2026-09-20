import SwiftUI

/// The Freeform-mode prompt overlay. Shows a single text field bound to
/// `AppState.freeformInstruction`. Pressing Enter submits and runs the
/// current action; Esc cancels.
///
/// The field auto-focuses on appear; previous instruction text is preserved
/// so the user can re-edit and re-run quickly.
struct FreeformPromptWindowView: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(colors: [Color.retypoAccent.opacity(0.12), Color.black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.retypoAccent.opacity(0.24), lineWidth: 1))
        .task(id: state.freeformPromptShowID) {
            // Wait for the NSPanel to actually become key + the SwiftUI host
            // to settle, then claim focus. Without the sleep, @FocusState
            // doesn't reliably fire on the second-and-later shows of the
            // same panel.
            try? await Task.sleep(nanoseconds: 120_000_000)
            fieldFocused = true
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.retypoAccent.opacity(0.9))
            TextField("Type instruction (e.g. translate to French and shorten)", text: $state.freeformInstruction)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($fieldFocused)
                .onSubmit { state.confirmFreeformPrompt() }
            Button("Cancel") { state.cancelFreeformPrompt() }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .pointingCursor()
            Button("Run") { state.confirmFreeformPrompt() }
                .buttonStyle(SettingsCapsuleButtonStyle(active: true))
                .pointingCursor()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
