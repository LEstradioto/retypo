import Foundation

struct PromptBufferExtractor {
    private let statusLines = PromptStatusLineClassifier()
    private let cleaner = PromptPaneTextCleaner()
    private let paneSlicer = PromptPaneSlicer()

    func prompt(from rawText: String) -> PromptCaptureCandidate? {
        let lines = normalizedLines(rawText)
        if let claude = claudeDividerPrompt(lines) { return claude }
        if let bottom = bottomPrompt(lines) { return bottom }
        return nil
    }

    func visibleBottomPrompt(from rawText: String) -> PromptCaptureCandidate? {
        PromptVisibleBottomExtractor().prompt(from: rawText)
    }

    private func normalizedLines(_ rawText: String) -> [String] {
        rawText.components(separatedBy: .newlines).map { $0.trimmedRight }
    }

    private func claudeDividerPrompt(_ lines: [String]) -> PromptCaptureCandidate? {
        guard let pair = dividerPairs(lines).last else { return nil }
        let range = arrowPaneRange(lines: lines, top: pair.top, bottom: pair.bottom)
        let sliced = (pair.top + 1..<pair.bottom).map { paneSlicer.slice(line: lines[$0], range: range) }
        let text = cleaner.text(from: ArraySlice(sliced))
        guard isUsable(text) else { return nil }
        return PromptCaptureCandidate(text: text, kind: .claudeDividerComposer)
    }

    private func dividerPairs(_ lines: [String]) -> [(top: Int, bottom: Int)] {
        let indexes = lines.indices.filter { isDividerLine(lines[$0]) }
        return indexes.flatMap { top in validDividerPairs(top: top, indexes: indexes) }
            .filter { encloses(promptMarker: lines, between: $0.top, and: $0.bottom) }
    }

    private func validDividerPairs(top: Int, indexes: [Int]) -> [(top: Int, bottom: Int)] {
        indexes.compactMap { bottom in
            let gap = bottom - top
            guard gap >= 2, gap <= 12 else { return nil }
            return (top: top, bottom: bottom)
        }
    }

    private func encloses(promptMarker lines: [String], between top: Int, and bottom: Int) -> Bool {
        (top + 1..<bottom).contains { paneSlicer.containsPromptMarker(lines[$0]) }
    }

    private func arrowPaneRange(lines: [String], top: Int, bottom: Int) -> PromptPaneSlicer.Range? {
        for index in (top + 1)..<bottom {
            if let range = paneSlicer.paneRange(forArrowIn: lines[index]) { return range }
        }
        return nil
    }

    private func bottomPrompt(_ lines: [String]) -> PromptCaptureCandidate? {
        guard let start = lastPromptMarkerIndex(lines) else { return nil }
        let range = paneSlicer.paneRange(forArrowIn: lines[start])
        let end = bottomPromptEnd(lines, start: start, paneRange: range)
        let sliced = (start...end).map { paneSlicer.slice(line: lines[$0], range: range) }
        let text = cleaner.text(from: ArraySlice(sliced))
        guard isUsable(text) else { return nil }
        return PromptCaptureCandidate(text: text, kind: .accessibilityTextBuffer)
    }

    private func bottomPromptEnd(_ lines: [String], start: Int, paneRange: PromptPaneSlicer.Range?) -> Int {
        var index = start
        while lines.indices.contains(index + 1) {
            let next = paneSlicer.slice(line: lines[index + 1], range: paneRange)
            guard shouldIncludeBottomLine(next, distance: index - start) else { break }
            index += 1
        }
        return index
    }

    private func shouldIncludeBottomLine(_ line: String, distance: Int) -> Bool {
        guard distance < 14 else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        if isLikelySplitPaneOnlyLine(line) { return true }
        return !isDividerLine(trimmed) && !isStatusLine(trimmed)
    }

    private func isLikelySplitPaneOnlyLine(_ line: String) -> Bool {
        let leadingSpaces = line.prefix(while: { $0.isWhitespace }).count
        return leadingSpaces >= 8
    }

    private func lastPromptMarkerIndex(_ lines: [String]) -> Int? {
        lines.indices.reversed().first { paneSlicer.containsPromptMarker(lines[$0]) }
    }

    private func isUsable(_ text: String) -> Bool {
        text.count >= 2 && text.filter(\.isLetter).count + text.filter(\.isNumber).count > 0
    }

    private func isDividerLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 8 else { return false }
        let count = trimmed.filter { dividerCharacters.contains($0) }.count
        return Double(count) / Double(trimmed.count) >= 0.45
    }

    private func isStatusLine(_ line: String) -> Bool {
        statusLines.isStatusLine(line)
    }

    private var dividerCharacters: Set<Character> {
        Set("─━═-=—_╭╮╰╯┌┐└┘")
    }
}

private extension String {
    var trimmedRight: String {
        String(reversed().drop(while: { $0.isWhitespace }).reversed())
    }
}
