import Foundation

struct PromptVisibleBottomExtractor {
    private let cleaner = PromptPaneTextCleaner()
    private let statusLines = PromptStatusLineClassifier()

    func prompt(from rawText: String) -> PromptCaptureCandidate? {
        let lines = normalizedLines(rawText)
        guard let range = visibleBottomRange(lines) else { return nil }
        let text = cleaner.text(from: lines[range])
        guard isUsable(text) else { return nil }
        return PromptCaptureCandidate(text: text, kind: .accessibilityTextBuffer)
    }

    private func normalizedLines(_ rawText: String) -> [String] {
        rawText.components(separatedBy: .newlines).map { $0.trimmedRight }
    }

    private func visibleBottomRange(_ lines: [String]) -> ClosedRange<Int>? {
        guard let end = lastVisiblePromptLineIndex(lines) else { return nil }
        var start = end
        while start > 0, shouldIncludeVisibleBottomLine(lines[start - 1], distance: end - start) {
            start -= 1
        }
        return start...end
    }

    private func lastVisiblePromptLineIndex(_ lines: [String]) -> Int? {
        lines.indices.reversed().first { isVisiblePromptLine(lines[$0]) }
    }

    private func isVisiblePromptLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !isDividerLine(trimmed) && !statusLines.isStatusLine(trimmed)
    }

    private func shouldIncludeVisibleBottomLine(_ line: String, distance: Int) -> Bool {
        guard distance < 14 else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        return !isDividerLine(trimmed) && !statusLines.isStatusLine(trimmed)
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

    private var dividerCharacters: Set<Character> {
        Set("─━═-=—_╭╮╰╯┌┐└┘")
    }
}

private extension String {
    var trimmedRight: String {
        String(reversed().drop(while: { $0.isWhitespace }).reversed())
    }
}
