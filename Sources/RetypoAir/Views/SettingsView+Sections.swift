import SwiftUI

extension SettingsView {
    var modelSection: some View {
        SettingsCard(title: "Model") {
            HStack(spacing: 12) {
                Picker("Provider", selection: Binding(get: { state.selectedProvider }, set: { state.selectedProvider = $0 })) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .frame(width: 170)
                .settingsFocus("model.provider", radius: 8, keyboardFocusable: true, activate: cycleProvider)

                Picker("Model", selection: Binding(get: { state.selectedModel ?? "" }, set: { if !$0.isEmpty { state.setSelectedModel($0) } })) {
                    Text("Select model...").tag("")
                    ForEach(state.llm.modelsByProvider[state.selectedProvider] ?? []) { Text($0.id).tag($0.id) }
                }
                .frame(maxWidth: .infinity)
                .settingsFocus("model.model", radius: 8, keyboardFocusable: true, activate: cycleModel)

                Button(state.llm.isLoadingModels ? "Loading" : "Refresh") { Task { await state.refreshModelsIfPossible() } }
                    .buttonStyle(SettingsCapsuleButtonStyle(active: false))
                    .settingsFocus("model.refresh", radius: 14, keyboardFocusable: true, activate: {
                        Task { await state.refreshModelsIfPossible() }
                        return true
                    })
                    .disabled(state.llm.isLoadingModels)
            }
        }
    }

    var editorSection: some View {
        SettingsCard(title: "Editor") {
            Picker("Theme", selection: Binding(get: { state.settings.mainTheme }, set: { state.setTheme($0) })) {
                ForEach(MainTheme.allCases) { Text($0.displayName).tag($0) }
            }
            .settingsFocus("editor.theme", radius: 8, keyboardFocusable: true, activate: cycleTheme)
            HStack(spacing: 8) {
                Text("Opacity")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.secondaryText)
                Slider(value: opacityBinding, in: 0.5...1.0, step: 0.05)
                    .settingsFocus("editor.opacity", radius: 8)
                Text("\(Int(state.settings.windowOpacity * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 40, alignment: .trailing)
            }
            HStack(spacing: 8) {
                ColorPicker("Font color", selection: fontColorBinding)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .settingsFocus("editor.fontColor", radius: 8)
                Button("Auto") { state.setFontColorHex(nil) }
                    .buttonStyle(SettingsCapsuleButtonStyle(active: state.settings.fontColorHex == nil))
                    .help("Follow the system text color")
            }
            editorToggleGrid
        }
    }

    private var opacityBinding: Binding<Double> {
        Binding(get: { state.settings.windowOpacity }, set: { state.setWindowOpacity($0) })
    }

    private var fontColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: state.editorFontColor) },
            set: { if let hex = FontColorHex.hex(from: $0) { state.setFontColorHex(hex) } }
        )
    }

    private var editorToggleGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                settingToggle("Auto copy result", focusID: "editor.autoCopy", keyPath: \.autoCopy)
                alwaysOnTopToggle
            }
            GridRow {
                settingToggle("Follow active display", focusID: "editor.followScreen", keyPath: \.followActiveScreenOnShow)
                settingToggle("Native macOS spellcheck", focusID: "editor.nativeSpellcheck", keyPath: \.nativeSpellcheck)
            }
            GridRow {
                settingToggle("Smart paste from clipboard", focusID: "editor.smartPaste", keyPath: \.smartPasteEnabled)
                KeyCaptureField(text: state.settings.smartPasteShortcut, commit: { state.claimSmartPasteShortcut($0) })
                    .settingsFocus("editor.smartPasteShortcut", radius: 8)
            }
        }
    }

    private func settingToggle(_ label: String, focusID: String, keyPath: WritableKeyPath<RetypoSettings, Bool>) -> some View {
        Toggle(label, isOn: settingBool(keyPath))
            .settingsFocus(focusID, radius: 8, keyboardFocusable: true, activate: {
                state.settings[keyPath: keyPath].toggle()
                state.saveSettings()
                return true
            })
    }

    private var alwaysOnTopToggle: some View {
        Toggle("Always on top", isOn: Binding(get: { state.settings.alwaysOnTop }, set: { _ in state.toggleAlwaysOnTop() }))
            .settingsFocus("editor.alwaysOnTop", radius: 8, keyboardFocusable: true, activate: {
                state.toggleAlwaysOnTop()
                return true
            })
    }

    var terminalImportSection: some View {
        SettingsCard(title: "Terminal import") {
            settingToggle(
                "Claude/Codex prompt import",
                focusID: "terminal.promptImport",
                keyPath: \.terminalPromptImportEnabled
            )
            settingToggle(
                "Experimental VS Code prompt import",
                focusID: "terminal.vscodeAccessibleView",
                keyPath: \.experimentalVSCodeAccessibleViewImport
            )
            Text("Claude/Codex import reads the terminal buffer. VS Code import briefly sends Option+F2, reads Accessible View, then presses Esc.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    /// Merged "shortcuts + cost" table. One row per model with columns:
    /// accept / id / shortcut / input $ per 1M / output $ per 1M.
    var accessSection: some View {
        SettingsCard(title: "Models · shortcut · cost") {
            HStack(spacing: 12) {
                LabeledShortcutField(label: "Previous model", focusID: "shortcuts.previousModel", text: Binding(get: { state.settings.previousModelShortcut }, set: { state.settings.previousModelShortcut = $0; state.saveSettings() }))
                LabeledShortcutField(label: "Next model", focusID: "shortcuts.nextModel", text: Binding(get: { state.settings.nextModelShortcut }, set: { state.settings.nextModelShortcut = $0; state.saveSettings() }))
            }
            accessSummary
            accessTable
        }
    }

    private var accessSummary: some View {
        HStack(spacing: 12) {
            Text("Last \(state.cost.lastCostLabel)")
            Text("Session \(state.cost.sessionCostLabel)")
            Text("Today \(state.cost.dayCostLabel)")
            Text("Tokens \(state.cost.lastCost.usage.totalTokens)")
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.secondaryText)
    }

    @ViewBuilder
    private var accessTable: some View {
        let models = state.llm.modelsByProvider[state.selectedProvider] ?? []
        if models.isEmpty {
            Text("Refresh models to set per-model access, shortcuts, and pricing.")
                .font(.system(size: 11)).foregroundStyle(Palette.secondaryText)
        } else {
            accessTableHeader
            VStack(spacing: 4) {
                ForEach(models.prefix(24)) { model in
                    accessRow(modelID: model.id)
                }
            }
        }
    }

    private var accessTableHeader: some View {
        HStack(spacing: 10) {
            Text("✓").frame(width: 18, alignment: .center)
            Text("Model").frame(maxWidth: .infinity, alignment: .leading)
            Text("Shortcut").frame(width: 120, alignment: .leading)
            Text("In $/M").frame(width: 76, alignment: .leading)
            Text("Out $/M").frame(width: 76, alignment: .leading)
        }
        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.secondaryText)
    }

    private func accessRow(modelID: String) -> some View {
        HStack(spacing: 10) {
            accessAcceptToggle(modelID)
            Text(modelID)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            accessShortcutField(modelID)
            accessPricingField(modelID, isInput: true)
            accessPricingField(modelID, isInput: false)
        }
    }

    private func accessAcceptToggle(_ modelID: String) -> some View {
        Toggle("", isOn: Binding(get: { state.isAcceptedModel(modelID) }, set: { _ in state.toggleAcceptedModel(modelID) }))
            .toggleStyle(.checkbox).labelsHidden()
            .frame(width: 18)
            .settingsFocus(modelFocusID(modelID, "accepted"), radius: 6, keyboardFocusable: true, activate: {
                state.toggleAcceptedModel(modelID); return true
            })
    }

    private func accessShortcutField(_ modelID: String) -> some View {
        TextField("cmd+opt+1", text: modelShortcutBinding(modelID))
            .textFieldStyle(.roundedBorder)
            .settingsFocus(modelFocusID(modelID, "shortcut"), radius: 6)
            .font(.system(size: 12, design: .monospaced)).frame(width: 120)
    }

    private func accessPricingField(_ modelID: String, isInput: Bool) -> some View {
        TextField("0.00", value: isInput ? pricingInputBinding(modelID) : pricingOutputBinding(modelID), format: .number)
            .textFieldStyle(.roundedBorder)
            .settingsFocus(modelFocusID(modelID, isInput ? "pricing.input" : "pricing.output"), radius: 6)
            .frame(width: 76)
    }
}
