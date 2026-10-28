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

    private static func sharedWhitespaceCount<Characters: Sequence>(_ first: Characters, _ second: Characters) -> Int
    where Characters.Element == Character {
        zip(first, second).prefix { $0 == $1 && $0.isWhitespace }.count
    }
}

/// Makes a token diff read like an editor's markup.
enum DiffCleanup {
    /// A word two replacements happen to share ("o" in "~~vamos ver~~ quero
    /// checar o ~~resultado~~ relatório") is noise in the review: shorter
    /// than both, it joins them, as in diff-match-patch's semantic cleanup.
    /// Only between replacements: a word kept between two removals or two
    /// insertions really was kept. A kept line break never joins, so edits
    /// in two paragraphs stay apart. The editor marks skip this step.
    static func absorbChaff(_ segments: [TextDiff.Segment]) -> [TextDiff.Segment] {
        var joined: [TextDiff.Segment] = []
        for segment in segments {
            joined.append(segment)
            while let merged = mergedTail(of: joined) {
                joined.removeLast(3)
                joined.append(merged)
            }
        }
        return joined
    }

    private static func mergedTail(of segments: [TextDiff.Segment]) -> TextDiff.Segment? {
        guard segments.count >= 3,
              let before = replacement(segments[segments.count - 3]),
              case .kept(let between) = segments[segments.count - 2],
              let after = replacement(segments[segments.count - 1])
        else { return nil }
        let shorterThanBoth = between.count < max(before.removed.count, before.added.count)
            && between.count < max(after.removed.count, after.added.count)
        guard shorterThanBoth, !between.contains(where: \.isNewline) else { return nil }
        return .edit(removed: before.removed + between + after.removed, added: before.added + between + after.added)
    }

    private static func replacement(_ segment: TextDiff.Segment) -> (removed: String, added: String)? {
        guard case .edit(let removed, let added) = segment, !removed.isEmpty, !added.isEmpty else { return nil }
        return (removed, added)
    }

    /// Replies come back trimmed (and drafts often end in a newline), so a
    /// whitespace-only edit at either end of the text is not a change.
    static func settleEdges(_ segments: [TextDiff.Segment]) -> [TextDiff.Segment] {
        var settled = segments
        for index in Set([settled.startIndex, settled.endIndex - 1]) where settled.indices.contains(index) {
            if case .edit(let removed, let added) = settled[index], (removed + added).allSatisfy(\.isWhitespace) {
                settled[index] = .kept(added)
            }
        }
        return joinKept(settled)
    }

    private static func joinKept(_ segments: [TextDiff.Segment]) -> [TextDiff.Segment] {
        segments.reduce(into: []) { joined, segment in
            guard case .kept(let text) = segment else { return joined.append(segment) }
            if text.isEmpty { return }
            if case .kept(let previous)? = joined.last {
                joined[joined.count - 1] = .kept(previous + text)
            } else {
                joined.append(segment)
            }
        }
    }
}
