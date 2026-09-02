import Foundation

enum ImportPreview {
    static func truncatedFirstVisibleLine(_ text: String, limit: Int = 120) -> String {
        let lines = text.split(whereSeparator: \.isNewline)
        guard let firstLine = lines.first else { return "" }
        let trimmedLine = String(firstLine).trimmingCharacters(in: .whitespaces)
        guard limit > 0, trimmedLine.count > limit else { return limit > 0 ? trimmedLine : "" }
        return String(trimmedLine.prefix(limit - 1)) + "…"
    }
}
