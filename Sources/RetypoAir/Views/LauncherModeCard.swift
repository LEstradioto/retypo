import SwiftUI

struct LauncherModeCard: View {
    @EnvironmentObject private var state: AppState

    let action: EditAction
    let width: CGFloat
    let selected: Bool
    let editing: Bool
    let select: () -> Void
    let edit: () -> Void
    let finishEditing: () -> Void
    let run: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if editing {
                LauncherModeEditor(action: action, finishEditing: finishEditing)
                    .environmentObject(state)
            } else {
                summary
            }
        }
        .padding(10)
        .frame(width: width, height: 176)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { if !editing { select() } }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(action.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                if selected { selectedLabel }
                if action.id != EditAction.freeformID { editButton }
            }
            Text(summaryInstruction)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(5)
            Spacer()
            Button("Run", action: run)
                .buttonStyle(.borderless)
                .pointingCursor()
        }
    }

    private var selectedLabel: some View {
        Text("selected")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.accentColor)
    }

    private var editButton: some View {
        Button(action: edit) {
            Image(systemName: "pencil")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .help("Edit \(action.title) here")
        .pointingCursor()
    }

    private var summaryInstruction: String {
        if action.id == EditAction.freeformID { return "Write a one-off prompt when you run this mode." }
        return action.instruction
    }

    private var cardFill: Color {
        selected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.08)
    }

    private var cardStroke: Color {
        selected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.12)
    }
}
