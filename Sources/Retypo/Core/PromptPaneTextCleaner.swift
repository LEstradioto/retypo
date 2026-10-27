import Foundation

struct PromptPaneTextCleaner {
    private let statusLines = PromptStatusLineClassifier()

    func text(from lines: ArraySlice<String>) -> String {
        let rawLines = Array(lines)
        let boundary = splitBoundary(in: rawLines)
        return rawLines.map { cleanedLine($0, boundary: boundary) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanedLine(_ line: String, boundary: Int?) -> String {
        let currentPane = currentPaneText(line, boundary: boundary)
        let withoutSuffix = trimmedForeignPaneSuffix(currentPane)
        let withoutBorder = withoutSuffix.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: borderSet)
        return stripPromptMarker(withoutBorder.trimmingCharacters(in: .whitespaces))
    }

    private func currentPaneText(_ line: String, boundary: Int?) -> String {
        guard let boundary, line.count > boundary else { return line }
        return String(line.prefix(boundary))
    }

    private func splitBoundary(in lines: [String]) -> Int? {
        let candidates = lines.compactMap(splitBoundaryCandidate)
        guard let cluster = bestBoundaryCluster(candidates), cluster.count >= 2 else { return nil }
        return cluster.min()
    }

    private func bestBoundaryCluster(_ candidates: [Int]) -> [Int]? {
        candidates.map { boundaryCluster(around: $0, candidates: candidates) }
            .max { $0.count < $1.count }
    }

    private func boundaryCluster(around candidate: Int, candidates: [Int]) -> [Int] {
        candidates.filter { abs($0 - candidate) <= 2 }
    }

    private func splitBoundaryCandidate(_ line: String) -> Int? {
        if let leading = leadingWhitespaceBoundary(line) { return leading }
        return internalWhitespaceBoundary(line)
    }

    private func leadingWhitespaceBoundary(_ line: String) -> Int? {
        let count = line.prefix(while: { $0.isWhitespace }).count
        guard count >= 8, line.count > count else { return nil }
        return count
    }

    private func internalWhitespaceBoundary(_ line: String) -> Int? {
        let chars = Array(line)
        var index = 0
        while index < chars.count {
            if let boundary = whitespaceBoundary(chars, from: &index) { return boundary }
            index += 1
        }
        return nil
    }

    private func whitespaceBoundary(_ chars: [Character], from index: inout Int) -> Int? {
        guard chars[index].isWhitespace else { return nil }
        let start = index
        while index < chars.count, chars[index].isWhitespace { index += 1 }
        guard index - start >= 4, index > 8, index < chars.count else { return nil }
        return index
    }

    private func trimmedForeignPaneSuffix(_ line: String) -> String {
        var index = line.startIndex
        while index < line.endIndex {
            if let trimmed = suffixTrimmedLine(line, at: index) { return trimmed }
            index = line.index(after: index)
        }
        return line
    }

    private func suffixTrimmedLine(_ line: String, at index: String.Index) -> String? {
        guard line[index].isWhitespace else { return nil }
        let suffix = String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)
        guard isForeignPaneSuffix(suffix) else { return nil }
        return String(line[..<index]).trimmedRight
    }

    private func isForeignPaneSuffix(_ text: String) -> Bool {
        let lower = text.lowercased()
        return statusLines.isStatusLine(text) || buildLogPrefixes.contains { lower.hasPrefix($0) }
    }

    private func stripPromptMarker(_ line: String) -> String {
        guard let first = line.first, promptMarkerPrefixes.contains(first),
              let second = line.dropFirst().first, second.isWhitespace else { return line }
        return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private var promptMarkerPrefixes: Set<Character> {
        Set(">›❯┃│")
    }

    private var buildLogPrefixes: [String] {
        ["[", "building for debugging", "build complete!", "built: /", "open it, then grant accessibility permission"]
    }

    private var borderSet: CharacterSet {
        CharacterSet(charactersIn: "│┃║▌▐▏▕╭╮╰╯┌┐└┘")
    }
}

private extension String {
    var trimmedRight: String {
        String(reversed().drop(while: { $0.isWhitespace }).reversed())
    }
}
