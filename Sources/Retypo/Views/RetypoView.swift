import SwiftUI

struct RetypoView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Palette.window.ignoresSafeArea()
            VStack(spacing: 0) {
                headerStrip
                editorBox(minHeight: 72)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
                if state.settings.liveTranslationEnabled {
                    TranslationCardView()
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)
                }
                footerStatus
            }
        }
        .tint(Color.retypoAccent)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }

    var statColor: Color {
        Palette.secondaryText
    }

    private func editorBox(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            NativeTextEditor(
                text: $state.inputText,
                nativeSpellcheck: state.settings.nativeSpellcheck,
                highlightRanges: state.inlineHighlightRanges,
                fontColor: state.editorFontColor,
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
            .fill(Palette.editor)
    }

    private var editorStroke: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .strokeBorder(Palette.hairline, lineWidth: 1)
    }
}
