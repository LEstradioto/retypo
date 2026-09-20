import Foundation

extension AppState {
    func handleShortcut(_ rawShortcut: String) -> Bool {
        let shortcut = ShortcutFormatter.normalize(rawShortcut)
        guard !shortcut.isEmpty else { return false }
        if matchesActionShortcut(shortcut) { return true }
        if matchesModelNavigationShortcut(shortcut) { return true }
        if matchesPerModelShortcut(shortcut) { return true }
        return false
    }

    private func matchesActionShortcut(_ shortcut: String) -> Bool {
        for action in enabledActions {
            if ShortcutFormatter.normalize(settings.shortcutByAction[action.id] ?? "") == shortcut {
                setCurrentAction(action.id)
                return true
            }
        }
        return false
    }

    private func matchesModelNavigationShortcut(_ shortcut: String) -> Bool {
        if ShortcutFormatter.normalize(settings.nextModelShortcut) == shortcut {
            selectAdjacentModel(direction: 1)
            return true
        }
        if ShortcutFormatter.normalize(settings.previousModelShortcut) == shortcut {
            selectAdjacentModel(direction: -1)
            return true
        }
        return false
    }

    private func matchesPerModelShortcut(_ shortcut: String) -> Bool {
        for provider in ProviderKind.allCases {
            for model in llm.modelsByProvider[provider] ?? [] {
                let key = settings.modelShortcutKey(provider: provider, modelID: model.id)
                if ShortcutFormatter.normalize(settings.shortcutByModel[key] ?? "") == shortcut {
                    setSelectedModel(model.id, provider: provider)
                    return true
                }
            }
        }
        return false
    }

    func toggleAlwaysOnTop() {
        settings.alwaysOnTop.toggle()
        host?.setAlwaysOnTop(settings.alwaysOnTop)
        saveSettings()
    }

    func copyOutput(_ text: String? = nil) {
        let value = (text ?? outputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        ClipboardService.copy(value)
        status = "Copied"
    }
}
