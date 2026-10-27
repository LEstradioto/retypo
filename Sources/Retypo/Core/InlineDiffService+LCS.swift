extension InlineDiffService {
    static func lcsPairs(_ old: [String], _ new: [String]) -> [(oldIndex: Int, newIndex: Int)] {
        guard !old.isEmpty, !new.isEmpty else { return [] }
        let table = lcsTable(old: old, new: new)
        return walkLCS(old: old, new: new, table: table)
    }

    private static func lcsTable(old: [String], new: [String]) -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: new.count + 1), count: old.count + 1)
        for oldIndex in stride(from: old.count - 1, through: 0, by: -1) {
            for newIndex in stride(from: new.count - 1, through: 0, by: -1) {
                table[oldIndex][newIndex] = old[oldIndex] == new[newIndex]
                    ? table[oldIndex + 1][newIndex + 1] + 1
                    : max(table[oldIndex + 1][newIndex], table[oldIndex][newIndex + 1])
            }
        }
        return table
    }

    private static func walkLCS(
        old: [String],
        new: [String],
        table: [[Int]]
    ) -> [(oldIndex: Int, newIndex: Int)] {
        var pairs: [(Int, Int)] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < old.count, newIndex < new.count {
            if old[oldIndex] == new[newIndex] { pairs.append((oldIndex, newIndex)); oldIndex += 1; newIndex += 1 }
            else if table[oldIndex + 1][newIndex] >= table[oldIndex][newIndex + 1] { oldIndex += 1 }
            else { newIndex += 1 }
        }
        return pairs
    }
}
