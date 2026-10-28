import Foundation

/// One step through both token lists: a token both keep, one removed from
/// the original, or one added in the revision.
enum DiffStep: Equatable {
    case keep, remove, add
}

/// The shortest way from the original tokens to the revised ones.
enum DiffAlignment {
    /// Past this many removed plus added tokens the changed middle shows as
    /// one replaced block: a rewrite that large reads better whole, and the
    /// Myers trace grows with its square (1,000 edits ≈ 8 MB, the ceiling
    /// the old one-million-cell LCS had). Text length alone never hits it:
    /// a few fixes in a 10,000-word draft stay exact.
    static let editLimit = 1_000

    static func steps(_ old: [Int], _ new: [Int]) -> [DiffStep] {
        let prefix = zip(old, new).prefix { $0.0 == $0.1 }.count
        let suffix = zip(old.dropFirst(prefix).reversed(), new.dropFirst(prefix).reversed()).prefix { $0.0 == $0.1 }.count
        let oldMiddle = Array(old[prefix ..< old.count - suffix])
        let newMiddle = Array(new[prefix ..< new.count - suffix])
        let middle = MyersDiff.steps(oldMiddle, newMiddle, editLimit: editLimit)
            ?? MyersDiff.replacement(removing: oldMiddle.count, adding: newMiddle.count)
        return Array(repeating: .keep, count: prefix) + middle + Array(repeating: .keep, count: suffix)
    }
}

/// Myers' O(ND) shortest edit script ("An O(ND) Difference Algorithm and
/// Its Variations", 1986): explore by number of edits, keep the furthest
/// point on each diagonal, then walk the saved frontiers back.
enum MyersDiff {
    /// Nil once more than `editLimit` tokens would be removed or added.
    static func steps(_ old: [Int], _ new: [Int], editLimit: Int) -> [DiffStep]? {
        if old.isEmpty || new.isEmpty { return replacement(removing: old.count, adding: new.count) }
        guard let trace = frontiers(old, new, editLimit: editLimit) else { return nil }
        return walkBack(trace, from: old.count, new.count)
    }

    static func replacement(removing removed: Int, adding added: Int) -> [DiffStep] {
        Array(repeating: .remove, count: removed) + Array(repeating: .add, count: added)
    }

    /// `trace[d]` is the frontier after d edits, for every d before the one
    /// that reached the end.
    private static func frontiers(_ old: [Int], _ new: [Int], editLimit: Int) -> [DiffFrontier]? {
        let maxEdits = min(old.count + new.count, editLimit)
        var live = DiffFrontier(reach: maxEdits + 1)
        var trace: [DiffFrontier] = []
        for edits in 0 ... maxEdits {
            for diagonal in stride(from: -edits, through: edits, by: 2) {
                let start = live.cameDown(onto: diagonal, edits: edits) ? live[diagonal + 1] : live[diagonal - 1] + 1
                let x = snake(from: start, on: diagonal, old, new)
                live[diagonal] = x
                if x >= old.count, x - diagonal >= new.count { return trace }
            }
            trace.append(live.snapshot(edits: edits))
        }
        return nil
    }

    /// Follows matching tokens down the diagonal (y = x − diagonal).
    private static func snake(from start: Int, on diagonal: Int, _ old: [Int], _ new: [Int]) -> Int {
        var x = start
        while x < old.count, x - diagonal < new.count, old[x] == new[x - diagonal] { x += 1 }
        return x
    }

    private static func walkBack(_ trace: [DiffFrontier], from oldCount: Int, _ newCount: Int) -> [DiffStep] {
        var reversed: [DiffStep] = []
        var x = oldCount
        var diagonal = oldCount - newCount
        for edits in stride(from: trace.count, to: 0, by: -1) {
            let previous = trace[edits - 1]
            let down = previous.cameDown(onto: diagonal, edits: edits)
            let fromDiagonal = down ? diagonal + 1 : diagonal - 1
            let fromX = previous[fromDiagonal]
            reversed += repeatElement(DiffStep.keep, count: x - (down ? fromX : fromX + 1))
            reversed.append(down ? .add : .remove)
            x = fromX
            diagonal = fromDiagonal
        }
        reversed += repeatElement(DiffStep.keep, count: x)
        return reversed.reversed()
    }
}

/// The furthest x reached on each diagonal k = x − y, for k in -reach...reach.
struct DiffFrontier {
    private var furthest: [Int]
    private let center: Int

    init(reach: Int) {
        furthest = Array(repeating: 0, count: 2 * reach + 1)
        center = reach
    }

    private init(furthest: [Int], center: Int) {
        self.furthest = furthest
        self.center = center
    }

    subscript(diagonal: Int) -> Int {
        get { furthest[center + diagonal] }
        set { furthest[center + diagonal] = newValue }
    }

    /// Whether the best path onto `diagonal` after `edits` edits came down
    /// from diagonal + 1 (adding a token) rather than right from
    /// diagonal − 1 (removing one). Reads the frontier of `edits` − 1.
    func cameDown(onto diagonal: Int, edits: Int) -> Bool {
        diagonal == -edits || (diagonal != edits && self[diagonal - 1] < self[diagonal + 1])
    }

    /// Only diagonals -edits...edits matter once `edits` edits are done.
    func snapshot(edits: Int) -> DiffFrontier {
        DiffFrontier(furthest: Array(furthest[center - edits ... center + edits]), center: edits)
    }
}
