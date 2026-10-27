import XCTest
@testable import Retypo

final class LegacyDataMigrationTests: XCTestCase {
    private var home: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        home = fileManager.temporaryDirectory.appendingPathComponent("retypo-home-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: home)
    }

    private var legacy: URL { AppFiles.legacyDirectory(inHome: home) }
    private var current: URL { AppFiles.directory(inHome: home) }

    private func writeLegacyFile(_ name: String, _ contents: String) throws {
        try fileManager.createDirectory(at: legacy, withIntermediateDirectories: true)
        try contents.write(to: legacy.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testMovesLegacyDirectoryWithItsFiles() throws {
        try writeLegacyFile("modes.json", "[]")
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .moved)
        let moved = try String(contentsOf: current.appendingPathComponent("modes.json"), encoding: .utf8)
        XCTAssertEqual(moved, "[]")
    }

    /// An older build still writing to `~/.retypo-air` must land in the same
    /// files as the new one, not in a fresh directory.
    func testLeavesASymlinkSoOldBuildsShareTheData() throws {
        try writeLegacyFile("draft.txt", "hello")
        try LegacyDataMigration.run(home: home)
        let destination = try fileManager.destinationOfSymbolicLink(atPath: legacy.path)
        XCTAssertEqual(URL(fileURLWithPath: destination).standardizedFileURL, current.standardizedFileURL)
        try "edited by old build".write(to: legacy.appendingPathComponent("draft.txt"), atomically: false, encoding: .utf8)
        XCTAssertEqual(try String(contentsOf: current.appendingPathComponent("draft.txt"), encoding: .utf8), "edited by old build")
    }

    func testSecondRunIsANoOp() throws {
        try writeLegacyFile("settings.json", "{}")
        try LegacyDataMigration.run(home: home)
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .alreadyMigrated)
    }

    func testFreshInstallHasNothingToMigrate() throws {
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .nothingToMigrate)
        XCTAssertFalse(fileManager.fileExists(atPath: current.path))
    }

    /// A test run once wrote `modes.json` into the real `~/.retypo`, which
    /// would have made the migration skip the user's `~/.retypo-air`.
    func testTestsNeverWriteToTheRealDataDirectory() {
        let real = AppFiles.directory(inHome: fileManager.homeDirectoryForCurrentUser)
        XCTAssertNotEqual(AppFiles.directory.standardizedFileURL, real.standardizedFileURL)
        XCTAssertTrue(AppFiles.directory.path.hasPrefix(fileManager.temporaryDirectory.path))
    }

    /// Both directories present (the user already ran a new build once):
    /// never overwrite the current data with the legacy copy.
    func testExistingCurrentDirectoryWins() throws {
        try writeLegacyFile("modes.json", "legacy")
        try fileManager.createDirectory(at: current, withIntermediateDirectories: true)
        try "current".write(to: current.appendingPathComponent("modes.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .keptBoth)
        XCTAssertEqual(try String(contentsOf: current.appendingPathComponent("modes.json"), encoding: .utf8), "current")
        XCTAssertEqual(try String(contentsOf: legacy.appendingPathComponent("modes.json"), encoding: .utf8), "legacy")
    }

    private func writeCurrentFile(_ name: String, _ contents: String) throws {
        try fileManager.createDirectory(at: current, withIntermediateDirectories: true)
        try contents.write(to: current.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func read(_ directory: URL, _ name: String) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }

    /// A stray `~/.retypo` (test artifacts, never used by the app) must not
    /// hide the user's real data: the old copies win, the stray ones are
    /// kept aside, and the old path becomes the link.
    func testUnusedCurrentDirectoryDoesNotHideTheUsersData() throws {
        try writeLegacyFile("settings.json", "{\"user\":true}")
        try writeLegacyFile("modes.json", "user modes")
        try writeLegacyFile(".env", "KEY=1")
        try writeCurrentFile("modes.json", "default modes")
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .merged)
        XCTAssertEqual(try read(current, "modes.json"), "user modes")
        XCTAssertEqual(try read(current, ".env"), "KEY=1")
        XCTAssertEqual(try read(current.appendingPathComponent("pre-migration"), "modes.json"), "default modes")
        XCTAssertNotNil(try? fileManager.destinationOfSymbolicLink(atPath: legacy.path))
    }

    /// Once the app has run on `~/.retypo`, its files win; only what the old
    /// directory alone has is brought over.
    func testCurrentDirectoryInUseOnlyGainsMissingFiles() throws {
        try writeLegacyFile("modes.json", "old modes")
        try writeLegacyFile("history.json", "old history")
        try writeCurrentFile("settings.json", "{}")
        try writeCurrentFile("modes.json", "new modes")
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .keptBoth, "logged: old modes stay behind")
        XCTAssertEqual(try read(current, "modes.json"), "new modes")
        XCTAssertEqual(try read(current, "history.json"), "old history")
        XCTAssertEqual(try read(legacy, "modes.json"), "old modes")
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .keptBoth)
    }

    /// `~/.retypo-air` as the user's own link into a dotfiles folder: point
    /// `~/.retypo` there too instead of starting over.
    func testUsersOwnLegacyLinkIsFollowed() throws {
        let synced = home.appendingPathComponent("dotfiles/retypo", isDirectory: true)
        try fileManager.createDirectory(at: synced, withIntermediateDirectories: true)
        try "synced modes".write(to: synced.appendingPathComponent("modes.json"), atomically: true, encoding: .utf8)
        try fileManager.createSymbolicLink(at: legacy, withDestinationURL: synced)
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .linked)
        XCTAssertEqual(try read(current, "modes.json"), "synced modes")
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .alreadyMigrated)
    }

    /// The user's own link, while `~/.retypo` is already in use: nothing
    /// moves, and the launch log says both were kept.
    func testUsersOwnLinkNextToAnExistingCurrentIsKept() throws {
        let synced = home.appendingPathComponent("dotfiles/retypo", isDirectory: true)
        try fileManager.createDirectory(at: synced, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: legacy, withDestinationURL: synced)
        try writeCurrentFile("settings.json", "{}")
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .keptBoth)
        XCTAssertEqual(try read(current, "settings.json"), "{}")
    }

    /// A move that fails halfway must not flip the winner on the retry:
    /// settings.json moves last, so the retry still sees the old side as
    /// the one the app used.
    func testAMergeThatFailsHalfwayResumesWithTheSameWinner() throws {
        try writeLegacyFile("settings.json", "user settings")
        try writeLegacyFile("modes.json", "user modes")
        try writeLegacyFile("history.json", "user history")
        try writeCurrentFile("modes.json", "default modes")
        XCTAssertThrowsError(try LegacyDataMigration.run(home: home, fileManager: FailingMoveFileManager(movesBeforeFailure: 1)))
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .merged)
        XCTAssertEqual(try read(current, "modes.json"), "user modes")
        XCTAssertEqual(try read(current, "history.json"), "user history")
        XCTAssertEqual(try read(current, "settings.json"), "user settings")
    }
}

/// Throws on the move after `movesBeforeFailure` successful ones.
final class FailingMoveFileManager: FileManager {
    private var remaining: Int

    init(movesBeforeFailure: Int) {
        remaining = movesBeforeFailure
        super.init()
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        guard remaining > 0 else { throw CocoaError(.fileWriteUnknown) }
        remaining -= 1
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
