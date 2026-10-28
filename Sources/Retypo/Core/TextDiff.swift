import Foundation

/// What a run changed, read word by word with punctuation, case and line
/// breaks, so "valor, e nossa" → "valor. Nossa" and a dropped phrase both
/// show. It replaced a words-only diff that lowercased everything, skipped
/// punctuation and could only point at new text, never at removed text.
///
///     TextDiff(original: "Agradecemos o contato.", revised: "Obrigado pelo contato.").segments
///     // [.edit(removed: "Agradecemos o", added: "Obrigado pelo"), .kept(" contato.")]
struct TextDiff: Hashable {
    /// Text both versions share, or one edit: what was removed and what took
    /// its place (either side may be empty).
    enum Segment: Hashable {
        case kept(String)
        case edit(removed: String, added: String)

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    static let none = TextDiff(original: "", revised: "")

    let segments: [Segment]
    let marks: ChangeMarks
    /// The text the marks describe: once the editor holds anything else,
    /// they point at the wrong characters.
    let revised: String

    init(original: String, revised: String) {
        segments = Self.segments(original: original, revised: revised)
        marks = ChangeMarks(segments)
        self.revised = revised
    }

    /// Separate places that changed; a replacement counts once.
    var editCount: Int { segments.filter(\.isEdit).count }

    var hasEdits: Bool { segments.contains(where: \.isEdit) }

    private static func segments(original: String, revised: String) -> [Segment] {
        guard original != revised else { return revised.isEmpty ? [] : [.kept(revised)] }
        let old = DiffTokens(original)
        let new = DiffTokens(revised)
        var interner = DiffTokenInterner()
        let oldIDs = interner.ids(for: old.tokens)
        let newIDs = interner.ids(for: new.tokens)
        let steps = DiffAlignment.steps(oldIDs, newIDs)
        return DiffCleanup.tidy(DiffSegmentBuilder.segments(steps: steps, old: old, new: new))
    }
}

/// Where the editor marks a run's edits, in UTF-16 offsets of the revised
/// text (NSTextView's units): added text to tint, and the points where text
/// was removed with nothing put in its place.
struct ChangeMarks: Hashable {
    private(set) var added: [NSRange] = []
    private(set) var removals: [Int] = []

    init() {}

    init(_ segments: [TextDiff.Segment]) {
        var offset = 0
        for segment in segments {
            switch segment {
            case .kept(let text):
                offset += text.utf16.count
            case .edit(_, let insertion) where insertion.isEmpty:
                removals.append(offset)
            case .edit(_, let insertion):
                added.append(Self.tintedRange(of: insertion, at: offset))
                offset += insertion.utf16.count
            }
        }
    }

    /// The added text without the spaces around it, so "cat " tints "cat".
    /// Added whitespace alone stays tinted: it is the whole edit.
    private static func tintedRange(of text: String, at offset: Int) -> NSRange {
        let length = text.utf16.count
        let leading = String(text.prefix(while: \.isWhitespace)).utf16.count
        guard leading < length else { return NSRange(location: offset, length: length) }
        let trailing = String(text.reversed().prefix(while: \.isWhitespace)).utf16.count
        return NSRange(location: offset + leading, length: length - leading - trailing)
    }
}
