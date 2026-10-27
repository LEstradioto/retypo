@testable import Retypo

final class RecordingDraftPersistence: DraftPersisting {
    private(set) var savedTexts: [String] = []
    private(set) var flushCount = 0
    private var storedText: String

    init(storedText: String = "") {
        self.storedText = storedText
    }

    func load() -> String {
        storedText
    }

    func save(_ text: String) {
        storedText = text
        savedTexts.append(text)
    }

    func flush() {
        flushCount += 1
    }
}
