import AppKit
import SwiftUI

@MainActor
final class AuxiliaryPanelController {
    weak var mainPanel: NSWindow?
    weak var state: AppState?
    let settingsFocus = SettingsFocusCoordinator()
    var settingsPanel: NSPanel?
    var candidatesPanel: NSPanel?
    var importPromptPanel: NSPanel?
    var freeformPromptPanel: NSPanel?

    init(mainPanel: NSWindow, state: AppState) {
        self.mainPanel = mainPanel
        self.state = state
    }

    func repositionCandidatesIfVisible() {
        if candidatesPanel?.isVisible == true, let candidatesPanel {
            positionCandidates(candidatesPanel)
        }
        if importPromptPanel?.isVisible == true, let importPromptPanel {
            positionImportPrompt(importPromptPanel)
        }
    }

    /// Order out every auxiliary panel without focusing the main editor.
    /// Called when the global hide hotkey is fired.
    func hideAll() {
        settingsPanel?.orderOut(nil)
        state?.showSettings = false
        candidatesPanel?.orderOut(nil)
        state?.showCandidateOverlay = false
        importPromptPanel?.orderOut(nil)
        freeformPromptPanel?.orderOut(nil)
    }

    func makePanel(width: CGFloat, height: CGFloat, minWidth: CGFloat, minHeight: CGFloat) -> KeyableAuxiliaryPanel {
        let panel = KeyableAuxiliaryPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: minWidth, height: minHeight)
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        return panel
    }

    func focusMainEditor() {
        guard let mainPanel else { return }
        NSApp.activate(ignoringOtherApps: true)
        mainPanel.makeKeyAndOrderFront(nil)
        if let editor = mainPanel.contentView?.firstSubview(of: KeyHandlingTextView.self) {
            mainPanel.makeFirstResponder(editor)
        } else {
            mainPanel.makeFirstResponder(mainPanel.contentView)
        }
    }

    func roundedHostingView<Content: View>(rootView: Content, radius: CGFloat) -> NSHostingView<Content> {
        let view = NSHostingView(rootView: rootView)
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
        return view
    }

    func positionSettings(_ panel: NSPanel) {
        guard let screen = mainPanel?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
    }

    func positionCandidates(_ panel: NSPanel) {
        guard let mainPanel else { return }
        let screen = mainPanel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let main = mainPanel.frame
        let horizontalPadding: CGFloat = visible.width < 420 ? 12 : 24
        let width = min(max(240, visible.width - horizontalPadding * 2), max(1, visible.width - 8))
        let height = max(154, min(230, visible.height * 0.24))
        let x = visible.midX - width / 2
        let y = min(visible.maxY - height - 16, main.maxY + 10)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    func positionImportPrompt(_ panel: NSPanel) {
        guard let mainPanel else { return }
        let screen = mainPanel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let main = mainPanel.frame
        let width = min(max(360, main.width), visible.width - 48)
        let height: CGFloat = 60
        let x = min(max(visible.minX + 24, main.midX - width / 2), visible.maxX - width - 24)
        let y = min(visible.maxY - height - 16, main.maxY + 10)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }
}

extension NSView {
    func firstSubview<T: NSView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }
}
