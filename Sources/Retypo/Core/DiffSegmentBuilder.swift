import Foundation

/// Turns alignment steps into kept text and edits. Each edit holds all it
/// removed and all it added, so a replacement reads "~~old~~ new" instead
/// of alternating word by word. A removed or added token carries the
/// whitespace before it; between two kept tokens the whitespace is compared.
enum DiffSegmentBuilder {
    static func segments(steps: [DiffStep], old: DiffTokens, new: DiffTokens) -> [TextDiff.Segment] {
        var builder = SegmentAccumulator()
        var oldIndex = 0
        var newIndex = 0
        for step in steps {
            switch step {
            case .keep: builder.gap(old.gaps[oldIndex], new.gaps[newIndex]); builder.keep(new.tokens[newIndex])
            case .remove: builder.remove(old.gaps[oldIndex] + old.tokens[oldIndex])
            case .add: builder.add(new.gaps[newIndex] + new.tokens[newIndex])
            }
            if step != .add { oldIndex += 1 }
            if step != .remove { newIndex += 1 }
        }
        builder.gap(old.gaps[oldIndex], new.gaps[newIndex])
        return builder.finish()
    }
}

/// Appends pieces in amortized O(1): a long kept run is one growing string,
/// not a copy per token.
private struct SegmentAccumulator {
    private var segments: [TextDiff.Segment] = []
    private var kept = ""
    private var removed = ""
    private var added = ""

    mutating func keep(_ piece: String) {
        closeEdit()
        kept += piece
    }

    mutating func remove(_ piece: String) {
        removed += piece
    }

    mutating func add(_ piece: String) {
        added += piece
    }

    mutating func gap(_ old: String, _ new: String) {
        guard old != new else { return keep(new) }
        remove(old)
        add(new)
    }

    mutating func finish() -> [TextDiff.Segment] {
        closeEdit()
        if !kept.isEmpty { segments.append(.kept(kept)) }
        return segments
    }

    /// Whitespace both sides of the edit share at its start stays with the
    /// kept text before it, and at its end with the kept text after it: a
    /// removed paragraph takes its own line break, not the one the next
    /// paragraph still has.
    /// Counts stay on Character sequences: rebuilding a String from reversed
    /// characters fused a trailing LF + CR into one CRLF and shifted every
    /// later mark. The shared whitespace is taken from the added side, which
    /// is the revised text the marks index into.
    private mutating func closeEdit() {
        guard !removed.isEmpty || !added.isEmpty else { return }
        let lead = Self.sharedWhitespaceCount(removed, added)
        let restRemoved = removed.dropFirst(lead)
        let restAdded = added.dropFirst(lead)
        let tail = Self.sharedWhitespaceCount(restRemoved.reversed(), restAdded.reversed())
        kept += added.prefix(lead)
        if !kept.isEmpty { segments.append(.kept(kept)) }
        let removedCore = String(restRemoved.dropLast(tail))
        let addedCore = String(restAdded.dropLast(tail))
        if !removedCore.isEmpty || !addedCore.isEmpty { segments.append(.edit(removed: removedCore, added: addedCore)) }
        kept = String(restAdded.suffix(tail))
        removed = ""
        added = ""
    }

    /// Two line breaks always count as shared, matching `DiffTokenInterner`:
    /// trimmed trailing spaces before "\r\n\r\n" in a draft answered with
    /// "\n\n" are one removal, not re-added breaks.
    private static func sharedWhitespaceCount<Characters: Sequence>(_ first: Characters, _ second: Characters) -> Int
    where Characters.Element == Character {
        zip(first, second).prefix { ($0 == $1 && $0.isWhitespace) || ($0.isNewline && $1.isNewline) }.count
    }
}
