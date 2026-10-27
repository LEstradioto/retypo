import AppKit
import SwiftUI

extension AuxiliaryPanelController {
    func showFreeformPrompt() {
        guard let state else { return }
        if freeformPromptPanel == nil { freeformPromptPanel = makeFreeformPromptPanel(state: state) }
        guard let freeformPromptPanel else { return }
        positionImportPrompt(freeformPromptPanel)  // same anchor as import prompt
        presentPanel(freeformPromptPanel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak freeformPromptPanel] in
            freeformPromptPanel?.makeKeyAndOrderFront(nil)
            freeformPromptPanel?.makeFirstResponder(freeformPromptPanel?.contentView)
        }
    }

    func hideFreeformPrompt(focusMain: Bool) {
        freeformPromptPanel?.orderOut(nil)
        if focusMain { focusMainEditor() }
    }

    func setFreeformPromptVisible(_ visible: Bool) {
        visible ? showFreeformPrompt() : hideFreeformPrompt(focusMain: true)
    }

    private func makeFreeformPromptPanel(state: AppState) -> KeyableAuxiliaryPanel {
        let panel = makePanel(width: 540, height: 64, minWidth: 360, minHeight: 56)
        panel.contentView = roundedHostingView(rootView: FreeformPromptWindowView().environmentObject(state), radius: 18)
        panel.onEnterKey = { [weak state] in
            state?.confirmFreeformPrompt()
            return true
        }
        panel.onCloseKey = { [weak state] in state?.cancelFreeformPrompt() }
        panel.onCommandSKey = { [weak state] in state?.cancelFreeformPrompt() }
        return panel
    }
}
