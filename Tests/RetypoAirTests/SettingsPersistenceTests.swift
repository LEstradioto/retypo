import XCTest
@testable import RetypoAir

private final class RecordingSettingsSaveBackend {
    private(set) var savedSettings: [RetypoSettings] = []

    func save(_ settings: RetypoSettings) {
        savedSettings.append(settings)
    }
}

final class SettingsPersistenceTests: XCTestCase {
    func testFilePersistenceUsesInjectedSaveOperation() {
        let backend = RecordingSettingsSaveBackend()
        let persistence = FileSettingsPersistence(saveOperation: backend.save)
        var settings = RetypoSettings()
        settings.autoCopy = false

        persistence.save(settings)

        XCTAssertEqual(backend.savedSettings, [settings])
    }
}
