import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    var state: AppState?
    var hotkeys: HotkeyService?
    var auxiliaryPanels: AuxiliaryPanelController?
    var previousApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        DebugLog.log("launch bundleID=\(Bundle.main.bundleIdentifier ?? "nil") bundlePath=\(Bundle.main.bundlePath) pid=\(ProcessInfo.processInfo.processIdentifier)")

        let settings = SettingsStore.load()
        let appState = AppState(settings: settings)
        self.state = appState

        let rootView = RetypoView()
            .environmentObject(appState)

        let panel = FloatingPanel(settings: settings)
        panel.contentView = NSHostingView(rootView: rootView)
        panel.delegate = self
        self.panel = panel
        let auxiliaryPanels = AuxiliaryPanelController(mainPanel: panel, state: appState)
        self.auxiliaryPanels = auxiliaryPanels

        appState.host = self
        registerHotkeys()

        showPanel()
        Task { await appState.refreshModelsIfPossible() }
    }

    private func registerHotkeys() {
        hotkeys = HotkeyService { [weak self] action in
            switch action {
            case .togglePanel:
                self?.togglePanel()
            }
        }
        hotkeys?.register()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        guard let draftPersistence = state?.draftPersistence else { return }
        draftPersistence.flush()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        focusEditorIfPossible()
    }

    func showPanel() {
        rememberPreviousApplication()
        guard let panel else { return }
        positionPanelForActiveScreenIfNeeded()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.focusEditorIfPossible()
        }
    }

    func hidePanelAndFocusPrevious() {
        panel?.orderOut(nil)
        auxiliaryPanels?.hideAll()
        if let previousApplication, !previousApplication.isTerminated {
            previousApplication.activate(options: [.activateIgnoringOtherApps])
        }
        state?.draftPersistence.flush()
    }

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible, NSApp.isActive, panel.isKeyWindow {
            hidePanelAndFocusPrevious()
        } else if let frontmost = NSWorkspace.shared.frontmostApplication,
                  frontmost.processIdentifier != NSRunningApplication.current.processIdentifier {
            DebugLog.log("togglePanel from external app; attempting selected-text import")
            importSelectedTextFromFrontmostApp(allowClipboardFallback: true)
        } else {
            showPanel()
        }
    }

    private func positionPanelForActiveScreenIfNeeded() {
        guard state?.settings.followActiveScreenOnShow == true, let panel else { return }
        let screen = screenForCurrentMouse() ?? panel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let width = max(280, visible.width / 3)
        let height = min(max(panel.frame.height, panel.minSize.height), visible.height * 0.55)
        let x = visible.minX + (visible.width - width) / 2
        let y = visible.minY + 34
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    private func screenForCurrentMouse() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    func focusEditorIfPossible() {
        guard state?.showSettings != true, panel?.isVisible == true else { return }
        guard let editor = panel?.contentView?.firstSubview(of: KeyHandlingTextView.self) else { return }
        panel?.makeFirstResponder(editor)
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Retypo Air")
        let quitItem = NSMenuItem(title: "Quit Retypo Air", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }
}

extension AppDelegate: PanelHost {
    func setAlwaysOnTop(_ enabled: Bool) {
        panel?.level = enabled ? .floating : .normal
    }
    func requestSettings() {
        auxiliaryPanels?.toggleSettings()
    }
    func setCandidatesVisible(_ visible: Bool) {
        auxiliaryPanels?.setCandidatesVisible(visible)
    }
    func setImportConfirmationVisible(_ visible: Bool) {
        auxiliaryPanels?.setImportPromptVisible(visible)
    }
    func setFreeformPromptVisible(_ visible: Bool) {
        auxiliaryPanels?.setFreeformPromptVisible(visible)
    }
    // requestHide is provided by hidePanelAndFocusPrevious below; this satisfies the protocol.
}

extension AppDelegate {
    func requestHide() { hidePanelAndFocusPrevious() }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) { focusEditorIfPossible() }
    func windowDidMove(_ notification: Notification) { persistFrame(); auxiliaryPanels?.repositionCandidatesIfVisible() }
    func windowDidResize(_ notification: Notification) { persistFrame(); auxiliaryPanels?.repositionCandidatesIfVisible() }
    func windowWillClose(_ notification: Notification) { persistFrame() }

    private func persistFrame() {
        guard let frame = panel?.frame, let state else { return }
        state.updatePanelFrame(frame)
    }
}
