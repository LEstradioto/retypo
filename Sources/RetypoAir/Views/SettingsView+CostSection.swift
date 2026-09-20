import SwiftUI

extension SettingsView {
    var historySection: some View {
        SettingsCard(title: "History") {
            historySectionHeader
            Text("Saved: \(state.history.count)/\(state.settings.historyLimit) LLM runs · \(state.draftSnapshots.count) draft backups")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.retypoAccent.opacity(0.85))
            if state.history.isEmpty && state.draftSnapshots.isEmpty {
                Text("No history yet.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.history) { entry in historyRow(entry) }
                    if !state.draftSnapshots.isEmpty {
                        Divider().opacity(0.3)
                        ForEach(state.draftSnapshots.prefix(5)) { snapshot in draftRow(snapshot) }
                    }
                }
            }
        }
    }

    private var historySectionHeader: some View {
        HStack {
            Text("LLM runs + realtime draft backups. Showing latest entries only; full file lives at ~/.retypo-air/history.json.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Save", selection: Binding(get: { state.settings.historyLimit }, set: { state.settings.historyLimit = $0; state.saveSettings() })) {
                Text("10").tag(10)
                Text("50").tag(50)
                Text("200").tag(200)
            }
            .pickerStyle(.segmented)
            .settingsFocus("history.limit", radius: 8, keyboardFocusable: true, activate: cycleHistoryLimit)
            .frame(width: 160)
            Button(historyDisplayMode.title) { historyDisplayMode = historyDisplayMode.next }
                .buttonStyle(SettingsCapsuleButtonStyle(active: false))
                .settingsFocus("history.display", radius: 14, keyboardFocusable: true, activate: {
                    historyDisplayMode = historyDisplayMode.next
                    return true
                })
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button { toggleHistoryExpanded(entry.id) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: expandedHistoryIDs.contains(entry.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        historyRowContent(entry)
                    }
                }
                .buttonStyle(.plain)
                .pointingCursor()
                Spacer()
                historyRowRestoreButton(entry)
            }
            if expandedHistoryIDs.contains(entry.id) {
                historyExpandedMessages(entry)
            }
        }
    }

    private func toggleHistoryExpanded(_ id: UUID) {
        if expandedHistoryIDs.contains(id) {
            expandedHistoryIDs.remove(id)
        } else {
            expandedHistoryIDs.insert(id)
        }
    }

    private func historyExpandedMessages(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            historyMessageBlock(title: "Input", text: entry.input)
            historyMessageBlock(title: "Output", text: entry.output)
            if !entry.diff.isEmpty {
                historyMessageBlock(title: "Diff", text: entry.diff)
            }
        }
        .padding(.leading, 16)
        .padding(.top, 4)
    }

    private func historyMessageBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.retypoAccent.opacity(0.85))
            Text(text.isEmpty ? "—" : text)
                .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.85))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.045)))
    }

    private func historyRowContent(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if entry.actionID == EditAction.freeformID {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.retypoAccent.opacity(0.9))
                }
                Text("\(entry.actionTitle) · \(entry.model)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            if let instruction = entry.instruction, !instruction.isEmpty {
                Text("“\(instruction)”")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(historyDisplayMode.text(for: entry))
                .font(.system(size: 12, weight: .regular, design: historyDisplayMode == .diff ? .monospaced : .default))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func historyRowRestoreButton(_ entry: HistoryEntry) -> some View {
        Button { state.restoreHistory(entry, useOutput: historyDisplayMode == .output) } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(SettingsIconButtonStyle())
        .settingsFocus(historyFocusID(entry.id), radius: 13, keyboardFocusable: true, activate: {
            state.restoreHistory(entry, useOutput: historyDisplayMode == .output)
            return true
        })
    }

    private func draftRow(_ snapshot: DraftSnapshot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Draft backup")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(snapshot.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                state.restoreDraftSnapshot(snapshot)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(SettingsIconButtonStyle())
            .settingsFocus(draftFocusID(snapshot.id), radius: 13, keyboardFocusable: true, activate: {
                state.restoreDraftSnapshot(snapshot)
                return true
            })
        }
    }
}
