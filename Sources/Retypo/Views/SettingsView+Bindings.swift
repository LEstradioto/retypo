import SwiftUI

extension SettingsView {
    func settingBool(_ keyPath: WritableKeyPath<RetypoSettings, Bool>) -> Binding<Bool> {
        Binding(get: { state.settings[keyPath: keyPath] }, set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() })
    }

    func pricingInputBinding(_ modelID: String) -> Binding<Double> {
        Binding(
            get: { state.pricingBindingValue(for: state.selectedProvider, model: modelID).inputPerMillion },
            set: { newValue in
                var value = state.pricingBindingValue(for: state.selectedProvider, model: modelID)
                value.inputPerMillion = newValue
                state.setPricing(value, provider: state.selectedProvider, model: modelID)
            }
        )
    }

    func pricingOutputBinding(_ modelID: String) -> Binding<Double> {
        Binding(
            get: { state.pricingBindingValue(for: state.selectedProvider, model: modelID).outputPerMillion },
            set: { newValue in
                var value = state.pricingBindingValue(for: state.selectedProvider, model: modelID)
                value.outputPerMillion = newValue
                state.setPricing(value, provider: state.selectedProvider, model: modelID)
            }
        )
    }

    func modelShortcutBinding(_ modelID: String) -> Binding<String> {
        let key = state.settings.modelShortcutKey(provider: state.selectedProvider, modelID: modelID)
        return Binding(
            get: { state.settings.shortcutByModel[key] ?? "" },
            set: { state.settings.shortcutByModel[key] = $0; state.saveSettings() }
        )
    }
}
