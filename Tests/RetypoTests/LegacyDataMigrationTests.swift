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
        XCTAssertEqual(try LegacyDataMigration.run(home: home), .alreadyMigrated)
        XCTAssertEqual(try String(contentsOf: current.appendingPathComponent("modes.json"), encoding: .utf8), "current")
        XCTAssertEqual(try String(contentsOf: legacy.appendingPathComponent("modes.json"), encoding: .utf8), "legacy")
    }
}
