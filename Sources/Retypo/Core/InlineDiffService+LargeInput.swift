import Foundation

extension InlineDiffService {
    static func shouldUseExactLCS(oldTokenCount: Int, newTokenCount: Int) -> Bool {
        guard oldTokenCount > 0, newTokenCount > 0 else { return true }
        return oldTokenCount <= exactLCSCellBudget / newTokenCount
    }

    static func coarseChangedRanges(
        oldTokens: [DiffToken],
        newTokens: [DiffToken]
    ) -> [NSRange] {
        let prefixCount = commonPrefixCount(oldTokens: oldTokens, newTokens: newTokens)
        let suffixCount = commonSuffixCount(
            oldTokens: oldTokens,
            newTokens: newTokens,
            prefixCount: prefixCount
        )
        let changedEnd = newTokens.count - suffixCount
        guard prefixCount < changedEnd else { return [] }
        return newTokens[prefixCount ..< changedEnd].map(\.range)
    }

    private static func commonPrefixCount(
        oldTokens: [DiffToken],
        newTokens: [DiffToken]
    ) -> Int {
        let maximumCount = min(oldTokens.count, newTokens.count)
        var count = 0
        while count < maximumCount, oldTokens[count].text == newTokens[count].text {
            count += 1
        }
        return count
    }

    private static func commonSuffixCount(
        oldTokens: [DiffToken],
        newTokens: [DiffToken],
        prefixCount: Int
    ) -> Int {
        let maximumCount = min(oldTokens.count, newTokens.count) - prefixCount
        var count = 0
        while count < maximumCount,
              oldTokens[oldTokens.count - count - 1].text == newTokens[newTokens.count - count - 1].text {
            count += 1
        }
        return count
    }
}
