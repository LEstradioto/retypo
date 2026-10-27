import Foundation

/// `list_files` output: one path per line with its size, capped.
enum ReferenceListing {
    /// Globs match the file name, or the whole path when they contain `/`.
    static func matches(_ file: ReferenceFile, pattern: String?) -> Bool {
        guard let pattern else { return true }
        let subject = pattern.contains("/") ? file.path : (file.path as NSString).lastPathComponent
        return fnmatch(pattern, subject, FNM_CASEFOLD) == 0
    }

    static func render(_ files: [ReferenceFile], limit: Int) -> String {
        guard !files.isEmpty else { return "No matching files." }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        var lines = files.prefix(limit).map { "\($0.path) (\(formatter.string(fromByteCount: Int64($0.byteSize))))" }
        if files.count > limit {
            lines.append("Showing \(limit) of \(files.count) files. Pass a folder path or a pattern such as \"*.md\" to narrow.")
        }
        return lines.joined(separator: "\n")
    }
}

/// `search_files`: literal alternatives, matched ignoring case and accents,
/// because notes mix "reembolso" with "Reembolsos" and "atenção" with
/// "atencao".
enum ReferenceSearch {
    static let lineCharacterLimit = 240

    /// `refund | Reembolso` → `["refund", "reembolso"]`.
    static func needles(from query: String) -> [String] {
        query.split(separator: "|")
            .map { fold(String($0)).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Keeps the first `limit` hits and counts the rest.
    struct Hits {
        let limit: Int
        private(set) var lines: [String] = []
        private(set) var total = 0

        init(limit: Int) {
            self.limit = limit
        }

        mutating func collect(from text: String, path: String, needles: [String]) {
            for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
                let folded = fold(String(line))
                guard needles.contains(where: folded.contains) else { continue }
                total += 1
                if lines.count < limit { lines.append("\(path):\(index + 1): \(line.prefix(lineCharacterLimit))") }
            }
        }

        func render(query: String) -> String {
            guard total > 0 else { return "No lines match \"\(query)\". Try another word, a synonym, or list_files." }
            guard total > lines.count else { return lines.joined(separator: "\n") }
            return (lines + ["\(lines.count) of \(total) matches shown. Use a more specific query or a path."]).joined(separator: "\n")
        }
    }
}

/// `read_file`: numbered lines from a window of the file.
enum ReferenceExcerpt {
    struct Window: Equatable {
        let first: Int
        let last: Int

        /// Lines are 1-based; a missing or inverted end reads `lineLimit` lines.
        init(start: Int?, end: Int?, lineLimit: Int) {
            let first = max(1, start ?? 1)
            let requested = end.map { max($0, first) } ?? first + lineLimit - 1
            self.first = first
            last = min(requested, first + lineLimit - 1)
        }
    }

    static func render(_ text: String, path: String, window: Window, characterLimit: Int) -> String {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard window.first <= lines.count else { return "\(path) has \(lines.count) lines; start_line \(window.first) is past the end." }
        var body: [String] = []
        var characters = 0
        var lastShown = window.first - 1
        for number in window.first...min(window.last, lines.count) where characters < characterLimit {
            let line = "\(number): \(lines[number - 1])"
            characters += line.count
            body.append(line)
            lastShown = number
        }
        return ([header(path, window.first, lastShown, lines.count)] + body + footer(lastShown, lines.count)).joined(separator: "\n")
    }

    private static func header(_ path: String, _ first: Int, _ last: Int, _ count: Int) -> String {
        "\(path) (lines \(first)-\(last) of \(count))"
    }

    private static func footer(_ lastShown: Int, _ count: Int) -> [String] {
        lastShown < count ? ["More below: call read_file with start_line \(lastShown + 1)."] : []
    }
}
