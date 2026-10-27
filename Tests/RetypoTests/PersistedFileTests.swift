import XCTest
@testable import Retypo

private struct TestRecord: Codable, Equatable {
    var name: String
    var count: Int
}

final class PersistedFileTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PersistedFileTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testLoadReturnsFallbackWhenFileMissing() {
        let file = PersistedFile<TestRecord>(
            url: tempDir.appendingPathComponent("missing.json"),
            fallback: TestRecord(name: "default", count: 0)
        )
        XCTAssertEqual(file.load(), TestRecord(name: "default", count: 0))
    }

    func testRoundTrip() {
        let file = PersistedFile<TestRecord>(
            url: tempDir.appendingPathComponent("record.json"),
            fallback: TestRecord(name: "fallback", count: -1)
        )
        let original = TestRecord(name: "live", count: 42)
        file.save(original)
        XCTAssertEqual(file.load(), original)
    }

    func testSaveCreatesParentDirectory() {
        let nested = tempDir
            .appendingPathComponent("a", isDirectory: true)
            .appendingPathComponent("b", isDirectory: true)
            .appendingPathComponent("rec.json")
        let file = PersistedFile<TestRecord>(url: nested, fallback: TestRecord(name: "x", count: 0))
        file.save(TestRecord(name: "nested", count: 7))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
        XCTAssertEqual(file.load(), TestRecord(name: "nested", count: 7))
    }

    func testMalformedJSONReturnsFallback() throws {
        let url = tempDir.appendingPathComponent("bad.json")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try "this is not json {".write(to: url, atomically: true, encoding: .utf8)
        let file = PersistedFile<TestRecord>(url: url, fallback: TestRecord(name: "fb", count: 99))
        XCTAssertEqual(file.load(), TestRecord(name: "fb", count: 99))
    }

    func testOverwritesExistingFile() {
        let file = PersistedFile<TestRecord>(
            url: tempDir.appendingPathComponent("record.json"),
            fallback: TestRecord(name: "fb", count: 0)
        )
        file.save(TestRecord(name: "v1", count: 1))
        file.save(TestRecord(name: "v2", count: 2))
        XCTAssertEqual(file.load(), TestRecord(name: "v2", count: 2))
    }

    func testArrayValueRoundTrip() {
        let file = PersistedFile<[TestRecord]>(
            url: tempDir.appendingPathComponent("array.json"),
            fallback: []
        )
        let values = [TestRecord(name: "a", count: 1), TestRecord(name: "b", count: 2)]
        file.save(values)
        XCTAssertEqual(file.load(), values)
    }

    func testAppFilesDirectoryUnderHome() {
        XCTAssertEqual(AppFiles.directory(inHome: URL(fileURLWithPath: "/Users/me")).path, "/Users/me/.retypo")
        XCTAssertEqual(AppFiles.url("foo.json").lastPathComponent, "foo.json")
    }
}
