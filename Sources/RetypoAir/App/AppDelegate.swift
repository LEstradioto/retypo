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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideAuxiliaryPanelsOnResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

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
        state?.flushPendingPanelFrame()
        state?.draftPersistence.flush()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Auxiliary popovers (Paste-confirm, Cmd+D, Settings) must not linger
    /// above other apps once Retypo loses focus. The main panel drops behind
    /// on its own; the `.floating` aux panels don't, so order them out here.
    @objc private func hideAuxiliaryPanelsOnResignActive() {
        auxiliaryPanels?.hideAll()
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
        state?.flushPendingPanelFrame()
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
        let screen = screenForFrontmostApp() ?? screenForCurrentMouse() ?? panel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let width = max(280, visible.width / 3)
        let height = min(max(panel.frame.height, panel.minSize.height), visible.height * 0.55)
        let x = visible.minX + (visible.width - width) / 2
        let y = visible.minY + 34
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    /// The screen holding the app you're working in — not the mouse, which
    /// often rests on the other display. Falls back to the mouse when
    /// Retypo itself (or nothing external) is frontmost.
    private func screenForFrontmostApp() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier,
              let center = mainWindowCenter(of: app.processIdentifier) else { return nil }
        return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
    }

    /// Center of an app's largest on-screen window, in Cocoa coordinates.
    /// Skips menu-bar extras and tooltips via a minimum size.
    private func mainWindowCenter(of pid: pid_t) -> NSPoint? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first(where: { $0.frame.minX == 0 && $0.frame.minY == 0 })?.frame.height else { return nil }
        var best: (area: CGFloat, center: NSPoint)?
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let center = Self.cocoaCenter(cgBounds: bounds, primaryHeight: primaryHeight) else { continue }
            let area = (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
            if best.map({ area > $0.area }) ?? true { best = (area, center) }
        }
        return best?.center
    }

    /// CG window bounds use a top-left origin; Cocoa screens use
    /// bottom-left of the primary display. Returns nil for tiny windows.
    nonisolated static func cocoaCenter(cgBounds bounds: [String: CGFloat], primaryHeight: CGFloat) -> NSPoint? {
        guard let x = bounds["X"], let y = bounds["Y"],
              let width = bounds["Width"], let height = bounds["Height"],
              width > 200, height > 200 else { return nil }
        return NSPoint(x: x + width / 2, y: primaryHeight - (y + height / 2))
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
    func setFreeformPromptVisible(_ visible: Bool) {
        auxiliaryPanels?.setFreeformPromptVisible(visible)
    }
    func setPanelAppearance(_ appearance: NSAppearance?) {
        panel?.appearance = appearance
        auxiliaryPanels?.setAllAppearances(appearance)
    }
    func setWindowOpacity(_ opacity: Double) {
        panel?.alphaValue = CGFloat(opacity)
    }
    // requestHide is provided by hidePanelAndFocusPrevious below; this satisfies the protocol.
}

extension AppDelegate {
    func requestHide() { hidePanelAndFocusPrevious() }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // The picker claims first responder for arrow keys; becoming key
        // again (Cmd+Tab back, dismissing a panel) must not steal it.
        guard state?.headerModePickerVisible != true else { return }
        focusEditorIfPossible()
    }
    func windowDidMove(_ notification: Notification) { persistFrame(); auxiliaryPanels?.repositionCandidatesIfVisible() }
    func windowDidResize(_ notification: Notification) { persistFrame(); auxiliaryPanels?.repositionCandidatesIfVisible() }
    func windowDidEndLiveResize(_ notification: Notification) {
        persistFrame()
        state?.flushPendingPanelFrame()
    }
    func windowWillClose(_ notification: Notification) {
        persistFrame()
        state?.flushPendingPanelFrame()
    }

    private func persistFrame() {
        guard let frame = panel?.frame, let state else { return }
        state.updatePanelFrame(frame)
    }
}
