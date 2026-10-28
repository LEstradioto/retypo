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
        var pieces: [String] = []
        var cursor = 0
        let everything = NSRange(location: 0, length: ns.length)
        ns.enumerateSubstrings(in: everything, options: [.byWords, .localized, .substringNotRequired]) { _, word, _, _ in
            appendGap(ns.substring(with: NSRange(location: cursor, length: word.location - cursor)), to: &pieces)
            pieces.append(ns.substring(with: word))
            cursor = NSMaxRange(word)
        }
        appendGap(ns.substring(from: cursor), to: &pieces)
        return pieces
    }

    /// Between two words: a run of whitespace is one piece, any other
    /// character (punctuation, symbol, emoji) one piece each.
    private static func appendGap(_ gap: String, to pieces: inout [String]) {
        var whitespace = ""
        for character in gap {
            if character.isWhitespace {
                whitespace.append(character)
                continue
            }
            if !whitespace.isEmpty { pieces.append(whitespace) }
            whitespace = ""
            pieces.append(String(character))
        }
        if !whitespace.isEmpty { pieces.append(whitespace) }
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
            if let known = numbers[piece] { return known }
            let next = numbers.count
            numbers[piece] = next
            return next
        }
    }
}
