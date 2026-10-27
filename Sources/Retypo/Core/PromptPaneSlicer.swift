import Foundation

struct PromptPaneSlicer {
    struct Range {
        let start: Int
        let end: Int
    }

    func arrowIndex(in chars: [Character]) -> Int? {
        guard chars.count >= 2 else { return nil }
        for i in 0..<(chars.count - 1) where chars[i + 1].isWhitespace {
            let c = chars[i]
            if c == "❯" || c == "›" { return i }
            if c == ">", i == 0 || isLeftNeighbor(chars[i - 1]) { return i }
        }
        return nil
    }

    func containsPromptMarker(_ line: String) -> Bool {
        arrowIndex(in: Array(line)) != nil
    }

    func paneRange(forArrowIn line: String) -> Range? {
        let chars = Array(line)
        guard let arrow = arrowIndex(in: chars) else { return nil }
        let leftPipe = (0..<arrow).reversed().first { isPaneBorder(chars[$0]) }
        let rightPipe = (arrow..<chars.count).first { isPaneBorder(chars[$0]) }
        return Range(
            start: leftPipe.map { $0 + 1 } ?? 0,
            end: rightPipe ?? Int.max
        )
    }

    func slice(line: String, range: Range?) -> String {
        guard let range else { return line }
        let chars = Array(line)
        let lo = min(range.start, chars.count)
        let hi = min(range.end, chars.count)
        guard lo < hi else { return "" }
        return String(chars[lo..<hi])
    }

    private func isLeftNeighbor(_ c: Character) -> Bool {
        c.isWhitespace || isPaneBorder(c)
    }

    private func isPaneBorder(_ c: Character) -> Bool {
        c == "│" || c == "┃" || c == "|"
    }
}
