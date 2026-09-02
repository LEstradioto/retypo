@testable import RetypoAir

final class RecordingWordCounter: WordCounting {
    private(set) var receivedTexts: [String] = []
    private let result: Int

    init(result: Int) {
        self.result = result
    }

    func countWords(in text: String) -> Int {
        receivedTexts.append(text)
        return result
    }
}
