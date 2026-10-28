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
    private mutating func closeEdit() {
        guard !removed.isEmpty || !added.isEmpty else { return }
        let lead = Self.sharedWhitespace(removed, added)
        let restRemoved = removed.dropFirst(lead.count)
        let restAdded = added.dropFirst(lead.count)
        let tail = String(Self.sharedWhitespace(String(restRemoved.reversed()), String(restAdded.reversed())).reversed())
        kept += lead
        if !kept.isEmpty { segments.append(.kept(kept)) }
        let edit = TextDiff.Segment.edit(removed: String(restRemoved.dropLast(tail.count)), added: String(restAdded.dropLast(tail.count)))
        if edit != .edit(removed: "", added: "") { segments.append(edit) }
        kept = tail
        removed = ""
        added = ""
    }

    private static func sharedWhitespace(_ first: String, _ second: String) -> String {
        String(zip(first, second).prefix { $0 == $1 && $0.isWhitespace }.map(\.0))
    }
}

/// Makes a token diff read like an editor's markup.
enum DiffCleanup {
    static func tidy(_ segments: [TextDiff.Segment]) -> [TextDiff.Segment] {
        settleEdges(absorbChaff(segments))
    }

    /// A stretch kept between two edits that is shorter than both (the
    /// spaces in "~~que~~ envolvido ~~poderá~~ nas") is noise: it joins the
    /// edits, as in diff-match-patch's semantic cleanup. A kept line break
    /// never joins, so edits in two paragraphs stay apart.
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
              case .edit(let removedBefore, let addedBefore) = segments[segments.count - 3],
              case .kept(let between) = segments[segments.count - 2],
              case .edit(let removedAfter, let addedAfter) = segments[segments.count - 1]
        else { return nil }
        let shorterThanBoth = between.count < max(removedBefore.count, addedBefore.count)
            && between.count < max(removedAfter.count, addedAfter.count)
        guard shorterThanBoth, !between.contains(where: \.isNewline) else { return nil }
        return .edit(removed: removedBefore + between + removedAfter, added: addedBefore + between + addedAfter)
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
