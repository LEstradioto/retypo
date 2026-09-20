import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settingsFocus: SettingsFocusCoordinator
    @State var historyDisplayMode: HistoryDisplayMode = .input
    @State var expandedHistoryIDs: Set<UUID> = []

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                LinearGradient(colors: [Color.white.opacity(0.18), Color.accentColor.opacity(0.035), Color.black.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    settingsHeader
                    ScrollView {
                        VStack(spacing: 14) {
                            modelSection
                            editorSection
                            terminalImportSection
                            accessSection
                            historySection
                        }
                        .padding(18)
                    }
                }
            }
            .onAppear {
                settingsFocus.setOrder(settingsFocusOrder)
                settingsFocus.focusFirst()
            }
            .onChange(of: settingsFocusOrder) { order in
                settingsFocus.setOrder(order)
            }
            .onChange(of: settingsFocus.focusedID) { focusedID in
                guard let focusedID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(focusedID, anchor: .center)
                }
            }
        }
    }

    var settingsFocusOrder: [String] {
        var ids: [String] = [
            "settings.done",
            "model.provider",
            "model.model",
            "model.refresh",
            "editor.theme",
            "editor.autoCopy",
            "editor.alwaysOnTop",
            "editor.followScreen",
            "editor.nativeSpellcheck",
            "terminal.promptImport",
            "terminal.vscodeAccessibleView",
            "shortcuts.previousModel",
            "shortcuts.nextModel"
        ]
        for model in (state.llm.modelsByProvider[state.selectedProvider] ?? []).prefix(24) {
            ids.append(modelFocusID(model.id, "accepted"))
            ids.append(modelFocusID(model.id, "shortcut"))
            ids.append(modelFocusID(model.id, "pricing.input"))
            ids.append(modelFocusID(model.id, "pricing.output"))
        }
        ids.append("history.limit")
        ids.append("history.display")
        ids.append(contentsOf: state.history.map { historyFocusID($0.id) })
        ids.append(contentsOf: state.draftSnapshots.prefix(5).map { draftFocusID($0.id) })
        return ids
    }

    func modelFocusID(_ modelID: String, _ field: String) -> String {
        "model.\(field).\(modelID)"
    }

    func historyFocusID(_ id: UUID) -> String {
        "history.restore.\(id.uuidString)"
    }

    func draftFocusID(_ id: UUID) -> String {
        "draft.restore.\(id.uuidString)"
    }

    func cycleProvider() -> Bool {
        guard let index = ProviderKind.allCases.firstIndex(of: state.selectedProvider) else { return false }
        state.selectedProvider = ProviderKind.allCases[(index + 1) % ProviderKind.allCases.count]
        return true
    }

    func cycleModel() -> Bool {
        let models = state.llm.modelsByProvider[state.selectedProvider] ?? []
        guard !models.isEmpty else {
            Task { await state.refreshModelsIfPossible() }
            return true
        }
        let current = state.selectedModel
        let index = models.firstIndex { $0.id == current } ?? -1
        state.setSelectedModel(models[(index + 1 + models.count) % models.count].id)
        return true
    }

    func cycleTheme() -> Bool {
        guard let index = MainTheme.allCases.firstIndex(of: state.settings.mainTheme) else { return false }
        state.settings.mainTheme = MainTheme.allCases[(index + 1) % MainTheme.allCases.count]
        state.saveSettings()
        return true
    }

    func cycleHistoryLimit() -> Bool {
        let values = [10, 50, 200]
        let index = values.firstIndex(of: state.settings.historyLimit) ?? 0
        state.settings.historyLimit = values[(index + 1) % values.count]
        state.saveSettings()
        return true
    }

    var settingsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Configure provider, shortcuts, and the main panel.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { state.requestSettings() }
                .buttonStyle(SettingsCapsuleButtonStyle(active: true))
                .settingsFocus("settings.done", radius: 16, keyboardFocusable: true, activate: {
                    state.requestSettings()
                    return true
                })
        }
        .padding(22)
    }
}
