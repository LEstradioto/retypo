import Foundation

enum InlineDiffService {
    struct DiffToken {
        let text: String
        let range: NSRange
    }

    static let exactLCSCellBudget = 1_000_000

    static func changedRanges(original: String, corrected: String) -> [NSRange] {
        guard original != corrected, !corrected.isEmpty else { return [] }
        let oldTokens = significantTokens(original)
        let newTokens = significantTokens(corrected)
        guard !newTokens.isEmpty else { return [] }

        return mergeNearby(changedTokenRanges(oldTokens: oldTokens, newTokens: newTokens))
    }

    private static func changedTokenRanges(
        oldTokens: [DiffToken],
        newTokens: [DiffToken]
    ) -> [NSRange] {
        guard shouldUseExactLCS(oldTokenCount: oldTokens.count, newTokenCount: newTokens.count) else {
            return coarseChangedRanges(oldTokens: oldTokens, newTokens: newTokens)
        }
        let keepPairs = lcsPairs(oldTokens.map(\.text), newTokens.map(\.text))
        let keptNewIndexes = Set(keepPairs.map(\.newIndex))
        return newTokens.enumerated().compactMap { index, token -> NSRange? in
            keptNewIndexes.contains(index) ? nil : token.range
        }
    }

    static func changedWordCount(original: String, corrected: String) -> Int {
        changedRanges(original: original, corrected: corrected).count
    }

    private static func significantTokens(_ text: String) -> [DiffToken] {
        let ns = text as NSString
        var tokens: [DiffToken] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .localized]) { substring, range, _, _ in
            guard let substring else { return }
            tokens.append(DiffToken(text: substring.lowercased(), range: range))
        }
        if tokens.isEmpty, !text.isEmpty {
            tokens.append(DiffToken(text: text.lowercased(), range: NSRange(location: 0, length: ns.length)))
        }
        return tokens
    }

    private static func mergeNearby(_ ranges: [NSRange]) -> [NSRange] {
        let sortedRanges = ranges.sorted { $0.location < $1.location }
        guard var current = sortedRanges.first else { return [] }
        var merged: [NSRange] = []
        for range in sortedRanges.dropFirst() {
            if range.location <= current.location + current.length + 2 {
                let end = max(current.location + current.length, range.location + range.length)
                current.length = end - current.location
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)
        return merged
    }
}
