import AppKit

final class FloatingPanel: NSPanel {
    init(settings: RetypoSettings) {
        super.init(
            contentRect: settings.panelFrame.nsRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        configureBaseAppearance()
        level = settings.alwaysOnTop ? .floating : .normal
        appearance = settings.mainTheme.nsAppearance
        alphaValue = CGFloat(settings.windowOpacity)
        hideStandardWindowButtons()
    }

    private func configureBaseAppearance() {
        title = "Retypo"
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        minSize = NSSize(width: 280, height: 78)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
    }

    private func hideStandardWindowButtons() {
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(kind)?.isHidden = true
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
