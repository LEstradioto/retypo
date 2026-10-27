import Foundation

struct VSCodeAccessibleViewClipboardParser {
    private let extractor = PromptBufferExtractor()

    func prompt(from text: String, marker: String) -> PromptCaptureCandidate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCopiedContent(trimmed, marker: marker) else { return nil }
        if let semanticPrompt = extractor.prompt(from: text) { return semanticPrompt }
        guard allowsVisibleBottomFallback(text) else { return nil }
        return extractor.visibleBottomPrompt(from: text)
    }

    private func isCopiedContent(_ text: String, marker: String) -> Bool {
        let isEmpty = text.isEmpty
        guard !isEmpty else { return false }
        let isMarker = text.hasPrefix(marker)
        guard !isMarker else { return false }
        return true
    }

    private func allowsVisibleBottomFallback(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let count = nonEmptyLines.count
        return count >= 2
    }
}
