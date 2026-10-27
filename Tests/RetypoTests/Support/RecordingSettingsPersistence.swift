@testable import Retypo

final class RecordingSettingsPersistence: SettingsPersisting {
    private(set) var savedSettings: [RetypoSettings] = []

    func save(_ settings: RetypoSettings) {
        savedSettings.append(settings)
    }
}
