import SwiftUI

/// Cmd+D mode picker, hosted in the main window header. Pills for every
/// enabled mode (arrows move, Enter runs), plus add / edit / delete and a
/// key-capture shortcut field per mode. Duplicate shortcuts are rejected
/// by `claimActionShortcut` with the owner shown inline.
struct HeaderModePicker: View {
    @EnvironmentObject var state: AppState
    @State private var editingModeID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModeStripKeyView(
                onLeft: { state.previousHeaderMode() },
                onRight: { state.nextHeaderMode() },
                onEnter: { Task { await state.runSelectedHeaderMode() }; ModeStripFocus.releaseToEditor() },
                onEscape: { state.headerModePickerVisible = false; ModeStripFocus.releaseToEditor() }
            )
            .frame(width: 0, height: 0)
            pillRow
            controlRow
            if let editing = editingAction {
                editorCard(editing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .onChange(of: state.headerModePickerVisible) { visible in
            if !visible { editingModeID = nil }
        }
    }

    private var pillRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(state.enabledActions.enumerated()), id: \.element.id) { index, action in
                        modePill(action, selected: index == state.headerModeIndex)
                            .id(action.id)
                    }
                }
                .padding(.vertical, 1)
            }
            .onChange(of: state.headerModeIndex) { index in
                guard state.enabledActions.indices.contains(index) else { return }
                withAnimation(.easeInOut(duration: 0.16)) {
                    proxy.scrollTo(state.enabledActions[index].id, anchor: .center)
                }
            }
        }
    }

    private func modePill(_ action: EditAction, selected: Bool) -> some View {
        Button {
            state.headerModeIndex = state.enabledActions.firstIndex(where: { $0.id == action.id }) ?? 0
            state.setCurrentAction(action.id)
            ModeStripFocus.claim()
        } label: {
            Text(action.title)
                .font(.system(size: 11, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(selected ? Color.white : Palette.primaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(
                    selected ? Color.retypoAccent : Palette.card))
                .overlay(Capsule(style: .continuous).strokeBorder(
                    selected ? Color.clear : Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            controlButton("plus", help: "Add mode") {
                state.addMode()
                editingModeID = state.currentAction.id
                syncHeaderIndexToCurrentAction()
            }
            controlButton("pencil", help: "Edit selected mode") {
                editingModeID = editingModeID == nil ? selectedAction?.id : nil
            }
            .disabled(selectedAction == nil)
            if let selected = selectedAction, selected.id != EditAction.freeformID {
                controlButton("trash", help: "Delete selected mode", destructive: true) {
                    state.deleteMode(selected)
                    editingModeID = nil
                    syncHeaderIndexToCurrentAction()
                }
                .disabled(state.actions.count <= 1)
            }
            if selectedAction != nil {
                KeyCaptureField(text: selectedShortcut, commit: commitSelectedShortcut)
                    .id(selectedAction?.id ?? "")
            }
            Spacer(minLength: 4)
            Text("←/→ choose · Enter runs · Esc closes")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
        }
    }

    private func editorCard(_ action: EditAction) -> some View {
        LauncherModeEditor(action: action) { editingModeID = nil }
            .environmentObject(state)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private func controlButton(_ systemName: String, help: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : Palette.primaryText)
                .frame(width: 22, height: 20)
                .background(Circle().fill(Palette.card))
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
        .pointingCursor()
    }

    private var selectedAction: EditAction? {
        guard state.enabledActions.indices.contains(state.headerModeIndex) else { return nil }
        return state.enabledActions[state.headerModeIndex]
    }

    private var editingAction: EditAction? {
        guard let editingModeID else { return nil }
        return state.actions.first(where: { $0.id == editingModeID })
    }

    private var selectedShortcut: String {
        guard let id = selectedAction?.id else { return "" }
        return state.settings.shortcutByAction[id] ?? ""
    }

    private func commitSelectedShortcut(_ shortcut: String) -> String? {
        guard let id = selectedAction?.id else { return "No mode" }
        return state.claimActionShortcut(shortcut, for: id)
    }

    private func syncHeaderIndexToCurrentAction() {
        state.headerModeIndex = state.enabledActions.firstIndex(where: { $0.id == state.currentAction.id }) ?? 0
    }
}
