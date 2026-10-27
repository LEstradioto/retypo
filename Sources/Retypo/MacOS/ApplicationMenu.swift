import AppKit

/// The menu bar: the app menu plus the standard Edit menu.
///
/// AppKit delivers Cmd+C/V/X/A/Z to text views as Edit-menu key equivalents.
/// Without that menu only the main editor got them, because it handles them
/// in its own `keyDown`; every other field (the mode prompt editor, Settings,
/// the Freeform prompt) beeped on Cmd+C, Cmd+V and Cmd+A.
@MainActor
enum ApplicationMenu {
    /// `NSTextView` answers these through the responder chain; `undo:` and
    /// `redo:` fall through to the window's undo manager.
    static let undoAction = Selector(("undo:"))
    static let redoAction = Selector(("redo:"))

    static func make(quit: NSMenuItem) -> NSMenu {
        let appMenu = NSMenu(title: "Retypo")
        appMenu.addItem(quit)
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu))
        mainMenu.addItem(submenuItem(editMenu()))
        return mainMenu
    }

    static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", action: undoAction, key: "z"))
        menu.addItem(item("Redo", action: redoAction, key: "z", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(item("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(item("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(item("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        return menu
    }

    /// Target `nil` sends the action to the first responder, so the item
    /// works in whichever text field or editor has focus.
    private static func item(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
