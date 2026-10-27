import AppKit

/// Keeps the main panel inside the visible screen after its content made it
/// taller.
///
/// `NSHostingView` raises the window's minimum height when the content needs
/// more room (a mode prompt dragged taller in the Cmd+D picker), and AppKit
/// grows the window downward from its top edge. A panel docked at the bottom
/// of the screen would then hang below the visible frame, so it moves back
/// up: in effect it grows upward instead.
enum PanelPlacement {
    /// Below this the offset is layout rounding, not a panel off screen.
    private static let tolerance: CGFloat = 0.5

    /// The frame shifted vertically into `visible`, or nil when it already
    /// fits. A panel taller than the screen keeps its top edge visible,
    /// because the header and the mode editor live there.
    static func onScreen(_ frame: NSRect, visible: NSRect) -> NSRect? {
        let minY = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        guard abs(minY - frame.minY) > tolerance else { return nil }
        return NSRect(x: frame.minX, y: minY, width: frame.width, height: frame.height)
    }
}
