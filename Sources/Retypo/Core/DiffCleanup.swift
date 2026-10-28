import Foundation

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

    /// Turns edits that change nothing a reader sees into kept text, taken
    /// from the added side so the marks still index the revision:
    /// - both sides read the same once line ends match (Thai and CJK words
    ///   can split differently after a restyled line break);
    /// - whitespace only, at either end of the text: replies come back
    ///   trimmed, and drafts often end in a newline.
    static func settle(_ segments: [TextDiff.Segment]) -> [TextDiff.Segment] {
        let edges = Set([segments.startIndex, segments.endIndex - 1])
        let settled = segments.enumerated().map { index, segment -> TextDiff.Segment in
            guard case .edit(let removed, let added) = segment else { return segment }
            let readsTheSame = DiffTokenInterner.normalizingLineBreaks(removed) == DiffTokenInterner.normalizingLineBreaks(added)
            let edgeWhitespace = edges.contains(index) && (removed + added).allSatisfy(\.isWhitespace)
            return readsTheSame || edgeWhitespace ? .kept(added) : segment
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
