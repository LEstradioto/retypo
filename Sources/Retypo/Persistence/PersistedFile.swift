import Foundation

/// A `Codable` value persisted as JSON in a file under the app's data directory.
///
/// Collapses what used to be 7 near-identical `*Store` enums (load/save with the
/// same JSON dance) behind a single deep module: every persisted entity goes
/// through `PersistedFile`, so file-IO bugs / encoding-options drift / atomic-write
/// behaviour live in exactly one place.
///
/// Errors during save are logged to stderr; the value in memory is the source of
/// truth, so a failed write is never fatal.
struct PersistedFile<Value: Codable> {
    let url: URL
    private let fallback: () -> Value

    init(url: URL, fallback: @autoclosure @escaping () -> Value) {
        self.url = url
        self.fallback = fallback
    }

    func load() -> Value {
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return fallback()
        }
        return value
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            fputs("Retypo \(url.lastPathComponent) save failed: \(error)\n", stderr)
        }
    }
}
