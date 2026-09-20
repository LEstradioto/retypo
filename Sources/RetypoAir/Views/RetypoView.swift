import SwiftUI

struct RetypoView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var colorScheme

    /// Light keeps the historic glass look. Dark deepens it.
    /// System follows the macOS appearance.
    var isDark: Bool {
        switch state.settings.mainTheme {
        case .dark: true
        case .glass: false
        case .system: colorScheme == .dark
        }
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                headerStrip
                editorBox(minHeight: 72)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
                footerStatus
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var background: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .ignoresSafeArea()
        LinearGradient(
            colors: isDark
                ? [Color.white.opacity(0.06), Color.black.opacity(0.22)]
                : [Color.white.opacity(0.13), Color.black.opacity(0.07)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var statColor: Color {
        Color.secondary.opacity(0.98)
    }

    private func editorBox(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            NativeTextEditor(
                text: $state.inputText,
                nativeSpellcheck: state.settings.nativeSpellcheck,
                highlightRanges: state.inlineHighlightRanges,
                onSubmit: { Task { await state.runCurrentAction(source: "enter") } },
                onRunAll: { Task { await state.runAllEnabledModes() } },
                onChange: { state.onInputChanged() },
                onCancel: { state.requestHide() },
                onTab: { if state.showCandidateOverlay { state.nextCandidate(); return true }; if state.footerFocusIndex != nil { state.nextFooterFocus(); return true }; return false },
                onShiftTab: { if state.showCandidateOverlay { state.previousCandidate(); return true }; if state.footerFocusIndex != nil { state.previousFooterFocus(); return true }; return false },
                onFocusCycle: { state.cycleFooterFocus() },
                onEnterInOverlay: { if state.footerFocusIndex != nil { state.activateFooterFocus(); return true }; if state.showCandidateOverlay { state.restoreSelectedCandidateToEditor(); return true }; return false },
                onToggleOverlay: { state.toggleModePicker() },
                onSettings: { state.requestSettings() },
                onUndo: { state.undoEditorChange() },
                onRedo: { state.redoEditorChange() },
                onShortcut: { state.handleShortcut($0) }
            )
            .frame(minHeight: minHeight)
            .background(editorBackground)
            .overlay(editorStroke)
        }
    }

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(isDark ? 0.62 : 0.54))
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 14)
    }

    private var editorStroke: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
    }
}
