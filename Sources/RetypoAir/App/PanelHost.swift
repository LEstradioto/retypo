import AppKit
import Foundation

/// The seam between domain state (`AppState`) and the AppKit panels that
/// present it. `AppState` asks the host to mutate UI; production wires
/// `AppDelegate` as the adapter, tests use `MockPanelHost`.
///
/// Two adapters justify the seam (per DEEPENING.md): production + test.
@MainActor
protocol PanelHost: AnyObject {
    func setAlwaysOnTop(_ enabled: Bool)
    func requestHide()
    func requestSettings()
    func setCandidatesVisible(_ visible: Bool)
    func setFreeformPromptVisible(_ visible: Bool)
    func setPanelAppearance(_ appearance: NSAppearance?)
    func setWindowOpacity(_ opacity: Double)
}
