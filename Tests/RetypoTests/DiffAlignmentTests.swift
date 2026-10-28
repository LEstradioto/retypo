import XCTest
@testable import Retypo

final class DiffAlignmentTests: XCTestCase {
    /// Longest common subsequence length, the textbook O(nm) way.
    private func referenceLCS(_ old: [Int], _ new: [Int]) -> Int {
        var table = Array(repeating: Array(repeating: 0, count: new.count + 1), count: old.count + 1)
        for i in old.indices.reversed() {
            for j in new.indices.reversed() {
                table[i][j] = old[i] == new[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        return table[0][0]
    }

    /// Replays the steps: they must consume both lists exactly, keep only
    /// equal tokens, and return how many they kept.
    private func replay(_ steps: [DiffStep], _ old: [Int], _ new: [Int]) -> Int? {
        var oldIndex = 0
        var newIndex = 0
        var kept = 0
        for step in steps {
            switch step {
            case .keep:
                guard oldIndex < old.count, newIndex < new.count, old[oldIndex] == new[newIndex] else { return nil }
                oldIndex += 1; newIndex += 1; kept += 1
            case .remove:
                guard oldIndex < old.count else { return nil }
                oldIndex += 1
            case .add:
                guard newIndex < new.count else { return nil }
                newIndex += 1
            }
        }
        return oldIndex == old.count && newIndex == new.count ? kept : nil
    }

    /// Myers must be both valid and shortest on every input, including the
    /// ones with many repeated tokens that real prose has (spaces, "de").
    func testMyersMatchesTheReferenceOnRandomInputs() {
        var generator = SeededGenerator(seed: 42)
        for _ in 0 ..< 1_500 {
            let old = (0 ..< Int.random(in: 0 ... 14, using: &generator)).map { _ in Int.random(in: 0 ... 3, using: &generator) }
            let new = (0 ..< Int.random(in: 0 ... 14, using: &generator)).map { _ in Int.random(in: 0 ... 3, using: &generator) }
            let steps = DiffAlignment.steps(old, new)
            XCTAssertEqual(replay(steps, old, new), referenceLCS(old, new), "old \(old) new \(new)")
        }
    }

    func testMyersGivesUpPastTheEditLimit() {
        let old = Array(0 ..< 10)
        let new = Array(10 ..< 20)
        XCTAssertNotNil(MyersDiff.steps(old, new, editLimit: 20))
        XCTAssertNil(MyersDiff.steps(old, new, editLimit: 19))
    }

    /// A few fixes in a long draft stay exact: the limit counts edits, not length.
    func testOneFixInTenThousandWordsStaysExact() {
        let original = Array(repeating: "alpha", count: 10_000).joined(separator: " ")
        var words = Array(repeating: "alpha", count: 10_000)
        words[5_000] = "bravo"
        words[9_000] = "charlie"
        let revised = words.joined(separator: " ")
        let diff = TextDiff(original: original, revised: revised)
        XCTAssertEqual(diff.marks.added.map { (revised as NSString).substring(with: $0) }, ["bravo", "charlie"])
    }

    /// Past the limit the changed middle is one replaced block, not noise.
    func testLargeRewriteIsOneBoundedEdit() {
        let original = Array(repeating: "alpha", count: 2_000).joined(separator: " ")
        let revised = Array(repeating: "bravo", count: 2_000).joined(separator: " ")
        let diff = TextDiff(original: original, revised: revised)
        XCTAssertEqual(diff.segments, [.edit(removed: original, added: revised)])
        XCTAssertEqual(diff.marks.added, [NSRange(location: 0, length: (revised as NSString).length)])
    }
}

/// A deterministic generator so the random cases are the same every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
