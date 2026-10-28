import XCTest
@testable import Retypo

final class ShortcutFormatterTests: XCTestCase {
    func testNormalizeAlreadyCanonical() {
        XCTAssertEqual(ShortcutFormatter.normalize("cmd+d"), "cmd+d")
    }

    func testNormalizeUppercaseAndSpaces() {
        XCTAssertEqual(ShortcutFormatter.normalize("CMD + D"), "cmd+d")
    }

    func testNormalizeAliasNames() {
        XCTAssertEqual(ShortcutFormatter.normalize("Command+Option+S"), "cmd+opt+s")
    }

    func testNormalizeUnicodeSymbols() {
        XCTAssertEqual(ShortcutFormatter.normalize("⌘D"), "cmd+d")
        XCTAssertEqual(ShortcutFormatter.normalize("⌘⇧Enter"), "cmd+shift+enter")
    }

    func testNormalizeReordersModifiers() {
        XCTAssertEqual(ShortcutFormatter.normalize("shift+cmd+a"), "cmd+shift+a")
    }

    func testNormalizeStripsTrailingPlus() {
        XCTAssertEqual(ShortcutFormatter.normalize("cmd+"), "cmd")
    }

    func testNormalizeEmpty() {
        XCTAssertEqual(ShortcutFormatter.normalize(""), "")
    }

    func testGlyphsPrintLikeMacOSMenus() {
        XCTAssertEqual(ShortcutFormatter.glyphs("cmd+2"), "⌘2")
        XCTAssertEqual(ShortcutFormatter.glyphs("cmd+shift+d"), "⌘⇧D")
        XCTAssertEqual(ShortcutFormatter.glyphs("Command+Option+]"), "⌘⌥]")
        XCTAssertEqual(ShortcutFormatter.glyphs("ctrl+space"), "⌃Space")
        XCTAssertEqual(ShortcutFormatter.glyphs(""), "")
    }
}
