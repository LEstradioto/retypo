import SwiftUI

extension SettingsView {
    var historySection: some View {
        SettingsCard(title: "History") {
            historySectionHeader
            Text("Saved: \(state.history.count)/\(state.settings.historyLimit) LLM runs · \(state.draftSnapshots.count) draft backups")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.accentColor.opacity(0.85))
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
        HStack(spacing: 10) {
            historyRowContent(entry)
            Spacer()
            historyRowRestoreButton(entry)
        }
    }

    private func historyRowContent(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if entry.actionID == EditAction.freeformID {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.9))
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
