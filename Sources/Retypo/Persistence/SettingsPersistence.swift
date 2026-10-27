protocol SettingsPersisting: AnyObject {
    func save(_ settings: RetypoSettings)
}

final class FileSettingsPersistence: SettingsPersisting {
    typealias SaveOperation = (RetypoSettings) -> Void

    private let saveOperation: SaveOperation

    init(saveOperation: @escaping SaveOperation = SettingsStore.save) {
        self.saveOperation = saveOperation
    }

    func save(_ settings: RetypoSettings) {
        saveOperation(settings)
    }
}
