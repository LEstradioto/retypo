import Foundation

/// Finds a CLI on disk.
///
/// A GUI app opened from Finder inherits a minimal `PATH`
/// (`/usr/bin:/bin:/usr/sbin:/sbin`) — not the login shell's — so `claude`
/// (`~/.local/bin`) and `codex` (`/opt/homebrew/bin`) are invisible to a plain
/// `which`. The usual install locations are searched explicitly instead.
enum CLIExecutableLocator {
    static var defaultSearchPaths: [String] {
        let home = NSHomeDirectory()
        return (ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []) + [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.bun/bin",
            "\(home)/.volta/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.nvm/versions/node/current/bin"
        ]
    }

    static func find(_ tool: String, searchPaths: [String] = defaultSearchPaths) -> URL? {
        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}
