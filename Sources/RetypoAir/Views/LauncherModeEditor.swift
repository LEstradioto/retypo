import SwiftUI

struct LauncherModeEditor: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var promptIsFocused: Bool

    let action: EditAction
    let finishEditing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("Mode name", text: titleBinding)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            TextEditor(text: instructionBinding)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .focused($promptIsFocused)
                .scrollContentBackground(.hidden)
                .padding(5)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            editorFooter
        }
        .onAppear {
            DispatchQueue.main.async { promptIsFocused = true }
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Label("Auto-saved", systemImage: "checkmark.circle.fill")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
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
