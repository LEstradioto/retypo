import Foundation

/// Moves the pre-rename `~/.retypo-air` directory to `~/.retypo` once, then
/// leaves a symlink at the old path. An older build that is still installed,
/// or still running while the new one starts, keeps reading and writing the
/// same files instead of silently starting over with defaults.
enum LegacyDataMigration {
    enum Outcome: Equatable {
        case moved
        /// Both existed; what only the old directory had was moved in.
        case merged
        /// `~/.retypo-air` was the user's own symlink (a dotfiles or sync
        /// folder); `~/.retypo` now points to the same place.
        case linked
        /// Both stay: `~/.retypo` is in use and the old directory still holds
        /// files it also has, or is the user's own link. Logged at every launch.
        case keptBoth
        case alreadyMigrated
        case nothingToMigrate
    }

    /// Runs before `DotEnvLoader`, which reads `.env` from the data directory.
    static func runAtLaunch() {
        guard AppFiles.overriddenDirectory == nil else { return }
        do {
            let outcome = try run(home: FileManager.default.homeDirectoryForCurrentUser)
            if outcome != .alreadyMigrated, outcome != .nothingToMigrate { DebugLog.log("legacy data migration: \(outcome)") }
        } catch {
            fputs("Retypo could not move ~/.retypo-air to ~/.retypo: \(error)\n", stderr)
        }
    }

    /// Idempotent: once `~/.retypo-air` is the link to `~/.retypo`, nothing happens.
    @discardableResult
    static func run(home: URL, fileManager: FileManager = .default) throws -> Outcome {
        let current = AppFiles.directory(inHome: home)
        let legacy = AppFiles.legacyDirectory(inHome: home)
        if let target = symlinkTarget(of: legacy, fileManager) { return try adopt(target, as: current, fileManager) }
        guard isRealDirectory(legacy, fileManager) else { return .nothingToMigrate }
        guard fileManager.fileExists(atPath: current.path) else {
            try fileManager.moveItem(at: legacy, to: current)
            try fileManager.createSymbolicLink(at: legacy, withDestinationURL: current)
            return .moved
        }
        try merge(legacy, into: current, fileManager)
        return isRealDirectory(legacy, fileManager) ? .keptBoth : .merged
    }

    /// The link this migration leaves behind, or the user's own link: then
    /// `~/.retypo` points to the same folder, which stays where it is.
    private static func adopt(_ target: URL, as current: URL, _ fileManager: FileManager) throws -> Outcome {
        let samePlace = current.resolvingSymlinksInPath().path == target.resolvingSymlinksInPath().path
        guard target.path != current.standardizedFileURL.path, !samePlace else { return .alreadyMigrated }
        guard !fileManager.fileExists(atPath: current.path) else { return .keptBoth }
        // A link into an unmounted volume or a deleted folder would leave
        // ~/.retypo pointing at nothing and every save failing; start fresh.
        guard isRealDirectory(target.resolvingSymlinksInPath(), fileManager) else { return .nothingToMigrate }
        try fileManager.createSymbolicLink(at: current, withDestinationURL: target)
        return .linked
    }

    /// Both exist: something created `~/.retypo` first (a test run, a
    /// hand-made `.env`). Files only the old directory has move in. When
    /// `~/.retypo` never served the app (no settings.json) and the old one
    /// did, the old copies win and the newer ones go to `pre-migration/`;
    /// otherwise the newer copies stay and the old ones are left in place.
    ///
    /// settings.json moves last: if a move fails halfway, the retry still
    /// sees it on the old side and picks the same winner.
    private static func merge(_ legacy: URL, into current: URL, _ fileManager: FileManager) throws {
        let legacyWins = !hasSettings(current, fileManager) && hasSettings(legacy, fileManager)
        let names = try fileManager.contentsOfDirectory(atPath: legacy.path)
        for name in names.filter({ $0 != settingsFile }) + names.filter({ $0 == settingsFile }) {
            let target = current.appendingPathComponent(name)
            if fileManager.fileExists(atPath: target.path) {
                guard legacyWins else { continue }
                try setAside(target, in: current, fileManager)
            }
            try fileManager.moveItem(at: legacy.appendingPathComponent(name), to: target)
        }
        try retireIfEmpty(legacy, pointingTo: current, fileManager)
    }

    private static let settingsFile = "settings.json"

    private static func setAside(_ item: URL, in current: URL, _ fileManager: FileManager) throws {
        let backup = current.appendingPathComponent("pre-migration", isDirectory: true)
        try fileManager.createDirectory(at: backup, withIntermediateDirectories: true)
        try fileManager.moveItem(at: item, to: backup.appendingPathComponent(item.lastPathComponent))
    }

    private static func retireIfEmpty(_ legacy: URL, pointingTo current: URL, _ fileManager: FileManager) throws {
        guard try fileManager.contentsOfDirectory(atPath: legacy.path).isEmpty else { return }
        try fileManager.removeItem(at: legacy)
        try fileManager.createSymbolicLink(at: legacy, withDestinationURL: current)
    }

    private static func hasSettings(_ directory: URL, _ fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: directory.appendingPathComponent(settingsFile).path)
    }

    private static func symlinkTarget(of url: URL, _ fileManager: FileManager) -> URL? {
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: url.path) else { return nil }
        return URL(fileURLWithPath: destination, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
    }

    /// `attributesOfItem` does not follow symlinks.
    private static func isRealDirectory(_ url: URL, _ fileManager: FileManager) -> Bool {
        let type = (try? fileManager.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
        return type == .typeDirectory
    }
}
