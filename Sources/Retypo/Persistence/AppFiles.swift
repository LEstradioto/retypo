import Foundation

/// The directory holding settings, modes, drafts, history and the optional
/// `.env`. It was `~/.retypo-air` until the Retypo Air → Retypo rename;
/// `LegacyDataMigration` moves an existing one over on first launch.
enum AppFiles {
    /// Points a second copy of the app (a dev build next to the installed
    /// one) at scratch data instead of the live directory. Example:
    /// `RETYPO_DATA_DIR=/tmp/retypo-scratch build-dev/Retypo-dev.app/Contents/MacOS/Retypo`
    static let overrideVariable = "RETYPO_DATA_DIR"

    static var directory: URL {
        if let override = overriddenDirectory { return override }
        return directory(inHome: FileManager.default.homeDirectoryForCurrentUser)
    }

    static var overriddenDirectory: URL? {
        if let raw = ProcessInfo.processInfo.environment[overrideVariable], !raw.isEmpty {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return isTestProcess ? testDirectory : nil
    }

    /// `AppState.init` and every mode edit save through the real stores, so
    /// a test run used to write `pricing.json` and `modes.json` into the
    /// live directory, and once created `~/.retypo` before the legacy data
    /// had migrated. Under XCTest everything goes to a per-run scratch folder.
    static var isTestProcess: Bool { ProcessInfo.processInfo.processName == "xctest" }

    private static let testDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("retypo-tests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)

    static func directory(inHome home: URL) -> URL {
        home.appendingPathComponent(".retypo", isDirectory: true)
    }

    static func legacyDirectory(inHome home: URL) -> URL {
        home.appendingPathComponent(".retypo-air", isDirectory: true)
    }

    static func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }
}
