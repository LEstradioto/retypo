import SwiftUI

struct LauncherModeEditor: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var promptIsFocused: Bool
    /// Live height while the grip is dragged. Committed to settings on
    /// release, so the whole panel does not re-render on every pixel.
    @State private var draggedPromptHeight: CGFloat?

    let action: EditAction
    let finishEditing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("Mode name", text: titleBinding)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            promptEditor
            if currentAction.canBeEnhanced {
                ModeEnhancementEditor(action: currentAction)
            }
            editorFooter
        }
        .onAppear {
            DispatchQueue.main.async { promptIsFocused = true }
        }
    }

    private var promptEditor: some View {
        TextEditor(text: instructionBinding)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .focused($promptIsFocused)
            .scrollContentBackground(.hidden)
            .padding(5)
            .frame(height: promptHeight)
            .background(RoundedRectangle(cornerRadius: 9).fill(Palette.editor))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.hairline, lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                TextareaResizeGrip(height: promptHeightBinding, range: RetypoSettings.modePromptHeightRange) { height in
                    state.setModePromptHeight(height)
                    draggedPromptHeight = nil
                }
            }
    }

    private var promptHeight: CGFloat {
        draggedPromptHeight ?? CGFloat(state.settings.modePromptHeight)
    }

    private var promptHeightBinding: Binding<CGFloat> {
        Binding(get: { promptHeight }, set: { draggedPromptHeight = $0 })
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Label("Auto-saved", systemImage: "checkmark.circle.fill")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.secondaryText)
            Spacer()
            if currentAction.hasCustomizedDefault {
                Button("Reset default") { resetToDefault() }
                    .buttonStyle(.borderless)
                    .help("Reset name and prompt to the built-in default")
            }
            Button("Done", action: finishEditing)
                .buttonStyle(.borderless)
        }
        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
    }

    private var titleBinding: Binding<String> {
        Binding(get: { currentAction.title }, set: { title in
            var updatedAction = currentAction
            updatedAction.title = title
            state.updateMode(updatedAction)
        })
    }

    private var instructionBinding: Binding<String> {
        Binding(get: { currentAction.instruction }, set: { instruction in
            var updatedAction = currentAction
            updatedAction.instruction = instruction
            state.updateMode(updatedAction)
        })
    }

    private var currentAction: EditAction {
        state.actions.first(where: { $0.id == action.id }) ?? action
    }

    private func resetToDefault() {
        var updatedAction = currentAction
        guard updatedAction.resetToDefault() else { return }
        state.updateMode(updatedAction)
    }
}
