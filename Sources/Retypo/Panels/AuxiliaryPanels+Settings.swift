import AppKit
import SwiftUI

extension AuxiliaryPanelController {
    func showSettings() {
        guard let state else { return }
        state.showSettings = true
        if settingsPanel == nil { settingsPanel = makeSettingsPanel(state: state) }
        guard let settingsPanel else { return }
        positionSettings(settingsPanel)
        presentPanel(settingsPanel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak settingsPanel] in
            guard let settingsPanel else { return }
            settingsPanel.makeKeyAndOrderFront(nil)
            settingsPanel.makeFirstResponder(settingsPanel.contentView)
            self?.settingsFocus.focusFirst()
        }
    }

    func hideSettings(focusMain: Bool = false) {
        settingsPanel?.orderOut(nil)
        state?.showSettings = false
        if focusMain { focusMainEditor() }
    }

    func toggleSettings() {
        if settingsPanel?.isVisible == true { hideSettings(focusMain: true) } else { showSettings() }
    }

    private func makeSettingsPanel(state: AppState) -> KeyableAuxiliaryPanel {
        let panel = makePanel(width: 780, height: 720, minWidth: 560, minHeight: 420)
        panel.contentView = roundedHostingView(rootView: SettingsView().environmentObject(state).environmentObject(settingsFocus), radius: 24)
        panel.onTabKey = { [weak self] in self?.settingsFocus.advance(reverse: false) }
        panel.onShiftTabKey = { [weak self] in self?.settingsFocus.advance(reverse: true) }
        panel.onEnterKey = { [weak self] in self?.settingsFocus.activateFocused() ?? false }
        panel.onCloseKey = { [weak self] in self?.hideSettings(focusMain: true) }
        panel.onCommandSKey = { [weak self] in self?.hideSettings(focusMain: true) }
        return panel
    }

    func presentPanel(_ panel: NSPanel) {
        NSApp.activate(ignoringOtherApps: true)
        panel.appearance = state?.settings.mainTheme.nsAppearance
        panel.makeKeyAndOrderFront(nil)
    }

    func setAllAppearances(_ appearance: NSAppearance?) {
        settingsPanel?.appearance = appearance
        candidatesPanel?.appearance = appearance
        freeformPromptPanel?.appearance = appearance
    }
}
