import Foundation

extension AppState {
    func handleShortcut(_ rawShortcut: String) -> Bool {
        let shortcut = ShortcutFormatter.normalize(rawShortcut)
        guard !shortcut.isEmpty else { return false }
        if matchesActionShortcut(shortcut) { return true }
        if matchesModelNavigationShortcut(shortcut) { return true }
        if matchesPerModelShortcut(shortcut) { return true }
        if matchesSmartPasteShortcut(shortcut) { return true }
        return false
    }

    /// Human-readable owner of a normalized shortcut, or nil when free.
    /// `excludingAction` skips one mode so re-saving its own combo passes.
    func shortcutOwner(_ shortcut: String, excludingAction actionID: String? = nil) -> String? {
        guard !shortcut.isEmpty else { return nil }
        if let owner = actionShortcutOwner(shortcut, excluding: actionID) { return owner }
        if let owner = modelShortcutOwner(shortcut) { return owner }
        if settings.smartPasteEnabled,
           ShortcutFormatter.normalize(settings.smartPasteShortcut) == shortcut { return "Smart paste" }
        return nil
    }

    private func actionShortcutOwner(_ shortcut: String, excluding actionID: String?) -> String? {
        for action in actions where action.id != actionID {
            if ShortcutFormatter.normalize(settings.shortcutByAction[action.id] ?? "") == shortcut {
                return "mode “\(action.title)”"
            }
        }
        return nil
    }

    private func modelShortcutOwner(_ shortcut: String) -> String? {
        if ShortcutFormatter.normalize(settings.nextModelShortcut) == shortcut { return "Next model" }
        if ShortcutFormatter.normalize(settings.previousModelShortcut) == shortcut { return "Previous model" }
        for (key, value) in settings.shortcutByModel where ShortcutFormatter.normalize(value) == shortcut {
            return "model \(key.components(separatedBy: "::").last ?? key)"
        }
        return nil
    }

    /// Assign a shortcut to a mode. Empty clears. Returns an error message
    /// when the combo belongs to someone else — the caller shows it inline.
    @discardableResult
    func claimActionShortcut(_ rawShortcut: String, for actionID: String) -> String? {
        let shortcut = ShortcutFormatter.normalize(rawShortcut)
        if shortcut.isEmpty {
            settings.shortcutByAction[actionID] = ""
            saveSettings()
            return nil
        }
        if let owner = shortcutOwner(shortcut, excludingAction: actionID) {
            status = "Shortcut taken by \(owner)"
            return "Taken by \(owner)"
        }
        settings.shortcutByAction[actionID] = shortcut
        saveSettings()
        status = "Shortcut \(shortcut)"
        return nil
    }

    /// Same guard for the smart-paste shortcut in Settings.
    @discardableResult
    func claimSmartPasteShortcut(_ rawShortcut: String) -> String? {
        let shortcut = ShortcutFormatter.normalize(rawShortcut)
        if shortcut.isEmpty {
            settings.smartPasteShortcut = ""
            saveSettings()
            return nil
        }
        if let owner = shortcutOwner(shortcut), owner != "Smart paste" {
            status = "Shortcut taken by \(owner)"
            return "Taken by \(owner)"
        }
        settings.smartPasteShortcut = shortcut
        saveSettings()
        status = "Smart paste \(shortcut)"
        return nil
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

    private func matchesSmartPasteShortcut(_ shortcut: String) -> Bool {
        guard settings.smartPasteEnabled else { return false }
        guard ShortcutFormatter.normalize(settings.smartPasteShortcut) == shortcut else { return false }
        doSmartPaste()
        return true
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
        refreshClipboardFlag()
        status = "Copied"
    }
}
