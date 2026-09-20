import AppKit
import SwiftUI

extension AuxiliaryPanelController {
    func showImportPrompt() {
        guard let state else { return }
        if importPromptPanel == nil { importPromptPanel = makeImportPromptPanel(state: state) }
        guard let importPromptPanel else { return }
        positionImportPrompt(importPromptPanel)
        presentPanel(importPromptPanel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak importPromptPanel] in
            importPromptPanel?.makeKeyAndOrderFront(nil)
            importPromptPanel?.makeFirstResponder(importPromptPanel?.contentView)
        }
    }

    func hideImportPrompt(focusMain: Bool) {
        importPromptPanel?.orderOut(nil)
        if focusMain { focusMainEditor() }
    }

    func setImportPromptVisible(_ visible: Bool) {
        visible ? showImportPrompt() : hideImportPrompt(focusMain: true)
    }

    private func makeImportPromptPanel(state: AppState) -> KeyableAuxiliaryPanel {
        let panel = makePanel(width: 480, height: 60, minWidth: 340, minHeight: 52)
        panel.contentView = roundedHostingView(rootView: ImportConfirmWindowView().environmentObject(state), radius: 14)
        panel.onEnterKey = { [weak state] in
            state?.confirmPendingImport()
            return true
        }
        panel.onCloseKey = { [weak state] in state?.cancelPendingImport() }
        panel.onCommandSKey = { [weak state] in state?.cancelPendingImport() }
        return panel
    }
}
