import AppKit
import SwiftUI
import XCTest
@testable import Retypo

@MainActor
final class ChangeMarksEditorTests: XCTestCase {
    private func editor(_ text: String) -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = text
        ChangeMarkPainter.install(on: textView)
        return textView
    }

    private func pins(of textView: NSTextView) -> RemovalMarkView? {
        textView.subviews.lazy.compactMap { $0 as? RemovalMarkView }.first
    }

    private func underline(_ textView: NSTextView, at index: Int) -> Any? {
        textView.layoutManager?.temporaryAttribute(.underlineStyle, atCharacterIndex: index, effectiveRange: nil)
    }

    func testAddedTextIsTintedAndRemovalsBecomePins() {
        let diff = TextDiff(original: "a estimativa de economia apresentada", revised: "a nova estimativa apresentada")
        let textView = editor(diff.revised)
        ChangeMarkPainter.apply(diff.marks, to: textView)
        XCTAssertNotNil(textView.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 2, effectiveRange: nil))
        XCTAssertEqual(pins(of: textView)?.offsets, diff.marks.removals)
        XCTAssertFalse(diff.marks.removals.isEmpty)
    }

    /// Clearing marks used to drop only the background, leaving the green
    /// underline on the old words once the user typed.
    func testClearingMarksRemovesTheUnderlineToo() {
        let diff = TextDiff(original: "the cat sat", revised: "the dog sat")
        let textView = editor(diff.revised)
        ChangeMarkPainter.apply(diff.marks, to: textView)
        XCTAssertNotNil(underline(textView, at: 4))
        ChangeMarkPainter.apply(ChangeMarks(), to: textView)
        XCTAssertNil(underline(textView, at: 4))
        XCTAssertEqual(pins(of: textView)?.offsets, [])
    }

    func testPinsIgnoreClicks() {
        let textView = editor("text")
        XCTAssertNil(pins(of: textView)?.hitTest(NSPoint(x: 10, y: 10)))
    }

    func testCaretRectFollowsTheText() throws {
        let textView = editor("ab\ncd")
        let start = try XCTUnwrap(textView.caretRect(at: 0))
        let afterB = try XCTUnwrap(textView.caretRect(at: 2))
        let secondLine = try XCTUnwrap(textView.caretRect(at: 3))
        let end = try XCTUnwrap(textView.caretRect(at: 5))
        XCTAssertGreaterThan(afterB.minX, start.minX)
        XCTAssertGreaterThan(secondLine.minY, start.minY)
        XCTAssertEqual(end.minY, secondLine.minY, accuracy: 0.5)
        XCTAssertNil(textView.caretRect(at: 6))
    }

    func testPinIsABarUnderADot() {
        let path = RemovalMarkView.pin(at: NSRect(x: 10, y: 0, width: 0, height: 18))
        XCTAssertEqual(path.bounds.midX, 10, accuracy: 0.01)
        XCTAssertEqual(path.bounds.height, 18, accuracy: 0.01)
    }

    func testTrackChangesStrikesRemovedTextAndMarksBreaks() {
        let diff = TextDiff(original: "fim.\n\n(Reescreva)", revised: "fim.")
        let text = TrackChanges.attributed(diff)
        XCTAssertEqual(String(text.characters), "fim.¶\n¶\n(Reescreva)")
        let struck = text.runs.filter { $0.swiftUI.strikethroughStyle != nil }.map { String(text[$0.range].characters) }
        XCTAssertEqual(struck, ["¶\n¶\n(Reescreva)"])
    }

    func testTrackChangesTintsAddedText() {
        let text = TrackChanges.attributed(TextDiff(original: "the cat", revised: "the dog"))
        let tinted = text.runs.filter { $0.swiftUI.underlineStyle != nil }.map { String(text[$0.range].characters) }
        XCTAssertEqual(tinted, ["dog"])
    }
}
