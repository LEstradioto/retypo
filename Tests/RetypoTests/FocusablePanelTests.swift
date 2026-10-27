import AppKit
import XCTest
@testable import Retypo

@MainActor
final class FocusablePanelTests: XCTestCase {
    func testTextEditorReceivesArrowInsteadOfLauncherNavigation() throws {
        let panel = makePanelWithTextEditor()
        var launcherNavigationCount = 0
        panel.onRightKey = { launcherNavigationCount += 1 }

        panel.sendEvent(try keyEvent(keyCode: 124, windowNumber: panel.windowNumber))

        XCTAssertEqual(launcherNavigationCount, 0)
    }

    func testTextEditorKeepsCandidateToggleShortcut() throws {
        let panel = makePanelWithTextEditor()
        var toggleCount = 0
        panel.onToggleCandidatesKey = { toggleCount += 1 }

        panel.sendEvent(try keyEvent(keyCode: 2, modifiers: .control, windowNumber: panel.windowNumber))

        XCTAssertEqual(toggleCount, 1)
    }

    private func makePanelWithTextEditor() -> KeyableAuxiliaryPanel {
        let panel = KeyableAuxiliaryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let textEditor = NSTextView(frame: panel.contentView?.bounds ?? .zero)
        panel.contentView?.addSubview(textEditor)
        panel.makeFirstResponder(textEditor)
        return panel
    }

    private func keyEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        windowNumber: Int
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: windowNumber, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false,
            keyCode: keyCode
        ))
    }
}
