import Foundation

enum DotEnvLoader {
    @discardableResult
    static func load() -> [String: String] {
        let bundleURL = Bundle.main.bundleURL
        let candidates = unique([
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"),
            Bundle.main.resourceURL?.appendingPathComponent(".env"),
            bundleURL.deletingLastPathComponent().appendingPathComponent(".env"),
            bundleURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".env"),
            SettingsStore.directory.appendingPathComponent(".env")
        ].compactMap(\.self))

        var loaded: [String: String] = [:]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            loaded.merge(loadFile(url)) { current, _ in current }
        }
        return loaded
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func loadFile(_ url: URL) -> [String: String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var values: [String: String] = [:]

        for rawLine in content.components(separatedBy: .newlines) {
            guard let pair = parseLine(rawLine) else { continue }
            values[pair.key] = pair.value
            setenv(pair.key, pair.value, 0) // shell env wins over .env
        }
        return values
    }

    private static func parseLine(_ rawLine: String) -> (key: String, value: String)? {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        if line.hasPrefix("export ") {
            line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
        }

        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        guard isValidKey(key) else { return nil }

        var value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
        value = stripInlineCommentIfUnquoted(value)
        value = unquote(value.trimmingCharacters(in: .whitespaces))
        return (key, value)
    }

    private static func isValidKey(_ key: String) -> Bool {
        guard let first = key.first, first == "_" || first.isLetter else { return false }
        return key.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    }

    private static func stripInlineCommentIfUnquoted(_ value: String) -> String {
        guard !value.hasPrefix("\"") && !value.hasPrefix("'") else { return value }
        guard let hash = value.firstIndex(of: "#") else { return value }
        let before = value[..<hash]
        if before.last?.isWhitespace == true {
            return String(before).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            let inner = String(value.dropFirst().dropLast())
            return inner
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        if value.hasPrefix("'") && value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
