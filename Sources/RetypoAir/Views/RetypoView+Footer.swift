import SwiftUI

extension RetypoView {
    var footerStatus: some View {
        HStack(spacing: 7) {
            modelMenu
            settingsButton

            Spacer(minLength: 6)
            if state.llm.isCorrecting { ProgressView().controlSize(.small) }
            undoButton
            redoButton
            costMenu
            footerStats
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        .foregroundStyle(Palette.secondaryText)
        .padding(.horizontal, 10)
        .padding(.top, 5)
        .padding(.bottom, 7)
    }

    private var modelMenu: some View {
        Menu {
            let models = state.navigableModels.isEmpty ? (state.llm.modelsByProvider[state.selectedProvider] ?? []) : state.navigableModels
            if models.isEmpty {
                Button("Refresh models") { Task { await state.refreshModelsIfPossible() } }
            } else {
                ForEach(models) { model in
                    Button(model.id) { state.setSelectedModel(model.id) }
                }
            }
        } label: {
            footerLink(state.modelLabel, active: state.selectedModel != nil, focused: state.footerFocusIndex == 0, maxWidth: 170)
        }
        .menuStyle(.borderlessButton)
        .background(Capsule(style: .continuous).fill(state.footerFocusIndex == 0 ? Color.retypoAccent.opacity(0.15) : Color.clear))
        .overlay(Capsule(style: .continuous).strokeBorder(state.footerFocusIndex == 0 ? Color.retypoAccent : Color.clear, lineWidth: 1))
    }

    private var settingsButton: some View {
        Button { state.requestSettings() } label: {
            footerSettingsIcon(focused: state.footerFocusIndex == 1)
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }

    private var undoButton: some View {
        Button { state.undoEditorChange() } label: {
            footerIcon("arrow.uturn.backward", active: state.canUndoEditorChange, focused: state.footerFocusIndex == 2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("z", modifiers: .command)
        .disabled(!state.canUndoEditorChange)
        .pointingCursor()
    }

    private var redoButton: some View {
        Button { state.redoEditorChange() } label: {
            footerIcon("arrow.uturn.forward", active: state.canRedoEditorChange, focused: state.footerFocusIndex == 3)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("Z", modifiers: [.command, .shift])
        .disabled(!state.canRedoEditorChange)
        .pointingCursor()
    }

    private var costMenu: some View {
        Menu {
            Text("Last: \(state.cost.lastCostLabel) · \(state.cost.lastCost.usage.totalTokens)t")
            Text("Session: \(state.cost.sessionCostLabel)")
            Text("Today: \(state.cost.dayCostLabel)")
        } label: {
            footerLink(costLabel, active: state.cost.lastCost.costUSD != nil || state.cost.lastCostIsSubscription, focused: state.footerFocusIndex == 4, maxWidth: 92)
        }
        .menuStyle(.borderlessButton)
    }

    /// "Last subscription" would not survive the footer's width, and the word
    /// alone already says the run cost no money.
    private var costLabel: String {
        state.cost.lastCostIsSubscription ? "Subscription" : "Last \(state.cost.lastCostLabel)"
    }

    private var footerStats: some View {
        Group {
            wpmText
            Text("Δ\(state.wordsChangedLast)")
                .foregroundStyle(state.wordsChangedLast == 0 ? statColor : Color.retypoAccent)
                .monospacedDigit()
            statusText
            Text("\(state.inputText.count)")
                .monospacedDigit()
                .foregroundStyle(statColor)
        }
    }

    /// WPM is hidden during the warm-up window (first ~5s of typing); avoids
    /// the misleading "200 wpm after one keystroke" artefact.
    @ViewBuilder
    private var wpmText: some View {
        if state.wordsPerMinute > 0 {
            Text("\(Int(state.wordsPerMinute))wpm")
                .foregroundStyle(statColor)
                .monospacedDigit()
        } else {
            Text("--wpm")
                .foregroundStyle(Palette.tertiaryText)
                .monospacedDigit()
        }
    }

    func footerLink(_ text: String, active: Bool, focused: Bool = false, maxWidth: CGFloat? = nil) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .foregroundStyle(active || focused ? Color.retypoAccent : Palette.secondaryText)
            .padding(.horizontal, focused ? 5 : 0)
            .padding(.vertical, focused ? 2 : 0)
            .background(Capsule(style: .continuous).fill(focused ? Color.retypoAccent.opacity(0.15) : Color.clear))
            .overlay(Capsule(style: .continuous).strokeBorder(focused ? Color.retypoAccent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .pointingCursor()
    }

    func footerIcon(_ systemName: String, active: Bool, focused: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(active || focused ? Color.retypoAccent : Palette.secondaryText)
            .frame(width: focused ? 18 : 14, height: 14)
            .background(Capsule(style: .continuous).fill(focused ? Color.retypoAccent.opacity(0.15) : Color.clear))
            .overlay(Capsule(style: .continuous).strokeBorder(focused ? Color.retypoAccent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .pointingCursor()
    }

    func footerSettingsIcon(focused: Bool = false) -> some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(focused ? Color.retypoAccent : Palette.secondaryText)
            .frame(width: focused ? 25 : 23, height: 18)
            .background(Capsule(style: .continuous).fill(focused ? Color.retypoAccent.opacity(0.15) : Palette.card))
            .overlay(Capsule(style: .continuous).strokeBorder(focused ? Color.retypoAccent : Palette.hairline, lineWidth: 1))
            .contentShape(Rectangle())
            .pointingCursor()
    }
}
