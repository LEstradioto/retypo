import AppKit
import XCTest
@testable import Retypo

/// Standard editing shortcuts must work in every text field, not only in
/// the main editor. AppKit routes them through the Edit menu's key
/// equivalents, so the menu is the contract under test.
@MainActor
final class EditingShortcutsTests: XCTestCase {
    private func editItem(key: String, modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem? {
        ApplicationMenu.editMenu().items.first {
            $0.keyEquivalent == key && $0.keyEquivalentModifierMask == modifiers
        }
    }

    func testClipboardAndSelectAllShortcutsReachAnyTextView() throws {
        let plainTextView = NSTextView()
        for key in ["x", "c", "v", "a"] {
            let action = try XCTUnwrap(editItem(key: key)?.action, "no Edit item for Cmd+\(key)")
            XCTAssertTrue(plainTextView.responds(to: action), "a plain NSTextView ignores Cmd+\(key)")
        }
    }

    /// `NSTextView` leaves `undo:` to the window, which owns the undo
    /// manager every SwiftUI text field registers its edits with.
    func testUndoAndRedoShortcutsReachTheWindow() throws {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        let undo = try XCTUnwrap(editItem(key: "z")?.action)
        let redo = try XCTUnwrap(editItem(key: "z", modifiers: [.command, .shift])?.action)
        XCTAssertTrue(window.responds(to: undo))
        XCTAssertTrue(window.responds(to: redo))
    }

    /// Cmd+Shift+V is the smart-paste shortcut; the Edit menu must not take it.
    func testSmartPasteShortcutStaysFree() {
        XCTAssertNil(editItem(key: "v", modifiers: [.command, .shift]))
    }

    func testMainMenuCarriesTheEditMenu() {
        let quit = NSMenuItem(title: "Quit Retypo", action: nil, keyEquivalent: "q")
        let titles = ApplicationMenu.make(quit: quit).items.compactMap { $0.submenu?.title }
        XCTAssertEqual(titles, ["Retypo", "Edit"])
    }

    /// The menu's Undo reaches the main editor before its `keyDown` does, so
    /// the editor must still fall back to the app-level history of mode
    /// results when its own text undo stack is empty.
    func testMainEditorMenuUndoFallsBackToAppHistory() {
        let editor = KeyHandlingTextView()
        var undoCount = 0
        var redoCount = 0
        editor.onUndo = { undoCount += 1; return true }
        editor.onRedo = { redoCount += 1; return true }
        editor.undo(nil)
        editor.redo(nil)
        XCTAssertEqual(undoCount, 1)
        XCTAssertEqual(redoCount, 1)
    }

    func testMainEditorKeepsUndoEnabledForAppHistory() {
        let editor = KeyHandlingTextView()
        let undo = NSMenuItem(title: "Undo", action: ApplicationMenu.undoAction, keyEquivalent: "z")
        XCTAssertTrue(editor.validateMenuItem(undo))
    }
}
