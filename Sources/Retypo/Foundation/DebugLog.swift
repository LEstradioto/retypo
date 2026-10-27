import Foundation

actor DebugLog {
    static let shared = DebugLog()

    private var fileURL: URL {
        SettingsStore.directory.appendingPathComponent("import-debug.log")
    }

    func write(_ message: String) {
        let line = "[\(Self.timestamp())] \(message)\n"
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try Data(line.utf8).write(to: fileURL, options: [.atomic])
            }
        } catch {
            fputs("Retypo debug log failed: \(error)\n", stderr)
        }
    }

    nonisolated static func log(_ message: String) {
        Task { await DebugLog.shared.write(message) }
    }

    private nonisolated static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
