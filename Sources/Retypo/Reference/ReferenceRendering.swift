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

    /// Where the earliest needle starts, in characters of the folded line.
    static func matchOffset(in folded: String, needles: [String]) -> Int? {
        needles.compactMap { folded.range(of: $0) }
            .map { folded.distance(from: folded.startIndex, to: $0.lowerBound) }
            .min()
    }

    /// The line itself when short; otherwise a window that starts a little
    /// before the match, so a hit deep in a long paragraph shows the hit.
    /// Folding can shift positions by a character (ß → ss); the window absorbs it.
    static func snippet(of line: Substring, around offset: Int) -> String {
        guard line.count > lineCharacterLimit else { return String(line) }
        let start = max(0, min(offset - lineCharacterLimit / 3, line.count - lineCharacterLimit))
        let from = line.index(line.startIndex, offsetBy: start)
        let window = line[from...].prefix(lineCharacterLimit)
        return (start > 0 ? "…" : "") + window + (start + lineCharacterLimit < line.count ? "…" : "")
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
            for (index, line) in ReferenceLines.lines(of: text).enumerated() {
                guard let offset = matchOffset(in: fold(String(line)), needles: needles) else { continue }
                total += 1
                if lines.count < limit { lines.append("\(path):\(index + 1): \(snippet(of: line, around: offset))") }
            }
        }

        func render(query: String) -> String {
            guard total > 0 else { return "No lines match \"\(query)\". Try another word, a synonym, or list_files." }
            guard total > lines.count else { return lines.joined(separator: "\n") }
            return (lines + ["\(lines.count) of \(total) matches shown. Use a more specific query or a path."]).joined(separator: "\n")
        }
    }
}

/// The line view search and read share. A physical line longer than
/// `width` (a Word paragraph, a minified JSON) becomes several numbered
/// lines, so every part of it can be found and read, and a search hit's
/// number is always a line `read_file` can open.
enum ReferenceLines {
    static let width = 2_000

    static func lines(of text: String) -> [Substring] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).flatMap(parts)
    }

    private static func parts(of line: Substring) -> [Substring] {
        guard line.count > width else { return [line] }
        var parts: [Substring] = []
        var start = line.startIndex
        while start < line.endIndex {
            let end = line.index(start, offsetBy: width, limitedBy: line.endIndex) ?? line.endIndex
            parts.append(line[start..<end])
            start = end
        }
        return parts
    }
}

/// `read_file`: numbered lines from a window of the file.
enum ReferenceExcerpt {
    struct Window: Equatable {
        /// No file has more lines; clamping first keeps the sums below Int.max.
        static let lastLine = 1_000_000_000

        let first: Int
        let last: Int

        /// Lines are 1-based; a missing or inverted end reads `lineLimit` lines.
        init(start: Int?, end: Int?, lineLimit: Int) {
            let first = min(max(1, start ?? 1), Self.lastLine)
            let windowEnd = first + lineLimit - 1
            self.first = first
            last = min(end.map { max($0, first) } ?? windowEnd, windowEnd)
        }
    }

    static func render(_ text: String, path: String, window: Window, characterLimit: Int) -> String {
        let lines = ReferenceLines.lines(of: text)
        guard window.first <= lines.count else { return "\(path) has \(lines.count) lines; start_line \(window.first) is past the end." }
        var body: [String] = []
        var characters = 0
        for number in window.first...min(window.last, lines.count) {
            let line = "\(number): \(lines[number - 1])"
            if characters + line.count > characterLimit, !body.isEmpty { break }
            characters += line.count
            body.append(line)
        }
        let lastShown = window.first + body.count - 1
        return ([header(path, window.first, lastShown, lines.count)] + body + footer(lastShown, lines.count)).joined(separator: "\n")
    }

    private static func header(_ path: String, _ first: Int, _ last: Int, _ count: Int) -> String {
        "\(path) (lines \(first)-\(last) of \(count))"
    }

    private static func footer(_ lastShown: Int, _ count: Int) -> [String] {
        lastShown < count ? ["More below: call read_file with start_line \(lastShown + 1)."] : []
    }
}
