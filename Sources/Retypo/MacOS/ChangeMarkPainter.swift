import AppKit

/// One palette for edits wherever they show: the editor's marks, the review
/// over it, and the run-all cards.
enum ChangeColors {
    static let addedTint = NSColor.systemGreen.withAlphaComponent(0.28)
    static let addedUnderline = NSColor.systemGreen.withAlphaComponent(0.60)
    static let removed = NSColor.systemRed
    static let removedTint = NSColor.systemRed.withAlphaComponent(0.12)
}

/// Shows a run's edits in the editable text without changing it: added text
/// tinted with temporary attributes, removals as pins drawn over the text.
enum ChangeMarkPainter {
    private static let tintAttributes: [NSAttributedString.Key] = [.backgroundColor, .underlineStyle, .underlineColor]

    static func install(on textView: NSTextView) {
        textView.addSubview(RemovalMarkView(textView: textView))
    }

    /// Clears every attribute it set before, underline included: clearing
    /// only the background once left green underlines behind after typing.
    static func apply(_ marks: ChangeMarks, to textView: NSTextView) {
        guard let layoutManager = textView.layoutManager else { return }
        let length = (textView.string as NSString).length
        let everything = NSRange(location: 0, length: length)
        tintAttributes.forEach { layoutManager.removeTemporaryAttribute($0, forCharacterRange: everything) }
        for range in marks.added where NSMaxRange(range) <= length {
            layoutManager.addTemporaryAttributes([
                .backgroundColor: ChangeColors.addedTint,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: ChangeColors.addedUnderline
            ], forCharacterRange: range)
        }
        let pins = textView.subviews.lazy.compactMap { $0 as? RemovalMarkView }.first
        pins?.offsets = marks.removals.filter { $0 <= length }
    }
}

/// A red pin wherever a run removed text and put nothing in its place, so
/// the removal shows in the result without being part of it. Sits on top of
/// the editor's text view and lets every click through.
final class RemovalMarkView: NSView {
    private weak var textView: NSTextView?

    var offsets: [Int] = [] {
        didSet { if offsets != oldValue { needsDisplay = true } }
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(frame: textView.bounds)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Rewrapping moves the pins with the text.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView, !offsets.isEmpty else { return }
        ChangeColors.removed.withAlphaComponent(0.85).setFill()
        for offset in offsets {
            guard let caret = textView.caretRect(at: offset) else { continue }
            Self.pin(at: caret).fill()
        }
    }

    /// A 2-pt bar the height of the line under a 5-pt dot: unlike the caret
    /// it is red, does not blink, and reads as "something was here".
    static func pin(at caret: NSRect) -> NSBezierPath {
        let bar = NSRect(x: caret.midX - 1, y: caret.minY + 2, width: 2, height: max(0, caret.height - 2))
        let path = NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1)
        path.append(NSBezierPath(ovalIn: NSRect(x: caret.midX - 2.5, y: caret.minY, width: 5, height: 5)))
        return path
    }
}

extension NSTextView {
    /// Where the insertion point would sit at `offset`, in this view's
    /// coordinates; nil past the end of the text.
    func caretRect(at offset: Int) -> NSRect? {
        guard let layoutManager, let textContainer, offset <= (string as NSString).length else { return nil }
        let point = NSRange(location: offset, length: 0)
        var count = 0
        guard let rects = layoutManager.rectArray(forCharacterRange: point, withinSelectedCharacterRange: point, in: textContainer, rectCount: &count),
              count > 0 else { return nil }
        return rects[0].offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }
}
