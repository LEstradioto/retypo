import Foundation

/// Cuts text into the pieces `TextDiff` compares: words as the system
/// segments them (so "we're" and CJK runs stay whole), each run of
/// whitespace, and every other character on its own. Joined back, the
/// pieces are the text, so punctuation and case are edits like any word.
///
///     DiffTokenizer.pieces(of: "valor, e nossa")  // ["valor", ",", " ", "e", " ", "nossa"]
enum DiffTokenizer {
    static func pieces(of text: String) -> [String] {
        let ns = text as NSString
        var collector = DiffPieceCollector()
        var cursor = 0
        let everything = NSRange(location: 0, length: ns.length)
        ns.enumerateSubstrings(in: everything, options: [.byWords, .localized, .substringNotRequired]) { _, word, _, _ in
            collector.gap(ns.substring(with: NSRange(location: cursor, length: word.location - cursor)))
            collector.word(ns.substring(with: word))
            cursor = NSMaxRange(word)
        }
        collector.gap(ns.substring(from: cursor))
        return collector.finish()
    }
}

/// Keeps every run of whitespace whole, however the system segments words:
/// in CJK text it reports line breaks and spaces as words of their own, so
/// "\r\n\u{2029}" was one piece on one side and two on the other.
private struct DiffPieceCollector {
    private var pieces: [String] = []
    private var whitespace = ""

    /// Between two words: whitespace extends the current run, any other
    /// character (punctuation, symbol, emoji) is a piece of its own.
    mutating func gap(_ text: String) {
        for character in text {
            if character.isWhitespace {
                whitespace.append(character)
                continue
            }
            flush()
            pieces.append(String(character))
        }
    }

    mutating func word(_ text: String) {
        if DiffTokenInterner.startsWithWhitespace(text), text.allSatisfy(\.isWhitespace) { return gap(text) }
        flush()
        pieces.append(text)
    }

    mutating func finish() -> [String] {
        flush()
        return pieces
    }

    private mutating func flush() {
        if !whitespace.isEmpty { pieces.append(whitespace) }
        whitespace = ""
    }
}

/// The pieces `TextDiff` aligns, with the spaces around them set apart.
/// Aligning on spaces too let a matching space win over a matching word
/// ("a ~~estimativa de economia~~ nova estimativa"); aligning words,
/// punctuation and line breaks first, then comparing the spaces between
/// kept ones, keeps the word ("a [nova] estimativa ~~de economia~~").
/// Line breaks stay aligned so an edit in each of two paragraphs stays two.
struct DiffTokens {
    /// Words, single punctuation marks and line-break runs, in order.
    private(set) var tokens: [String] = []
    /// `gaps[i]` is the run of spaces before `tokens[i]`; the last one
    /// trails the text, so there is always one more gap than tokens.
    private(set) var gaps: [String] = [""]

    init(_ text: String) {
        for piece in DiffTokenizer.pieces(of: text) {
            if piece.first?.isWhitespace == true, !piece.contains(where: \.isNewline) {
                gaps[gaps.count - 1] += piece
            } else {
                tokens.append(piece)
                gaps.append("")
            }
        }
    }
}

/// Gives equal pieces the same number, so the alignment compares integers
/// instead of strings.
struct DiffTokenInterner {
    private var numbers: [String: Int] = [:]

    mutating func ids(for pieces: [String]) -> [Int] {
        pieces.map { piece in
            let key = Self.matchKey(piece)
            if let known = numbers[key] { return known }
            let next = numbers.count
            numbers[key] = next
            return next
        }
    }

    /// CRLF, CR and the Unicode line separators match a plain LF: a draft
    /// pasted with Windows or classic Mac line ends against an LF reply
    /// would otherwise turn every paragraph break into an edit. Kept text
    /// comes from the revision, so the marks still index its own breaks.
    static func matchKey(_ piece: String) -> String {
        // Only whitespace runs hold line breaks; a word needs no scan.
        guard startsWithWhitespace(piece) else { return piece }
        return normalizingLineBreaks(piece)
    }

    static func normalizingLineBreaks(_ text: String) -> String {
        guard text.contains(where: \.isNewline) else { return text }
        return String(text.map { $0.isNewline ? "\n" : $0 })
    }

    /// The first scalar decides, as `Character.isWhitespace` does, without
    /// walking grapheme clusters for every word.
    static func startsWithWhitespace(_ text: String) -> Bool {
        text.unicodeScalars.first?.properties.isWhitespace == true
    }
}
