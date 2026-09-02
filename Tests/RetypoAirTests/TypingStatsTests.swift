import XCTest
@testable import RetypoAir

final class LocalizedWordCounterTests: XCTestCase {
    func testCountsLocalizedWordsAcrossPunctuationAndWhitespace() {
        let counter = LocalizedWordCounter()

        XCTAssertEqual(counter.countWords(in: "Hello, café!\nHow are you?"), 5)
    }

    func testEmptyTextHasNoWords() {
        let counter = LocalizedWordCounter()

        XCTAssertEqual(counter.countWords(in: ""), 0)
    }
}

@MainActor
final class TypingStatsTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_000)

    func testWarmupHidesWPMWithoutCountingWords() {
        let wordCounter = RecordingWordCounter(result: 2)
        let state = makeState(wordCounter: wordCounter)
        state.wordsPerMinute = 42
        state.typingStartedAt = referenceDate

        state.updateTypingStats(at: referenceDate.addingTimeInterval(4))

        XCTAssertEqual(state.wordsPerMinute, 0)
        XCTAssertTrue(wordCounter.receivedTexts.isEmpty)
    }

    func testRefreshesAtMostTwicePerSecond() {
        let wordCounter = RecordingWordCounter(result: 2)
        let state = makeState(wordCounter: wordCounter)
        state.inputText = "one two"
        state.typingStartedAt = referenceDate.addingTimeInterval(-10)

        state.updateTypingStats(at: referenceDate)
        state.updateTypingStats(at: referenceDate.addingTimeInterval(0.49))
        state.updateTypingStats(at: referenceDate.addingTimeInterval(0.5))

        XCTAssertEqual(wordCounter.receivedTexts, ["one two", "one two"])
    }

    func testTwoHundredFastKeyEventsBoundWordScans() {
        let wordCounter = RecordingWordCounter(result: 2)
        let state = makeState(wordCounter: wordCounter)
        state.inputText = String(repeating: "word ", count: 2_000)
        state.typingStartedAt = referenceDate.addingTimeInterval(-10)

        for eventIndex in 0 ..< 200 {
            let eventDate = referenceDate.addingTimeInterval(Double(eventIndex) * 0.05)
            state.updateTypingStats(at: eventDate)
        }

        XCTAssertLessThanOrEqual(wordCounter.receivedTexts.count, 20)
        XCTAssertFalse(wordCounter.receivedTexts.isEmpty)
    }

    func testRefreshCalculatesWordsPerMinuteFromSessionStart() {
        let wordCounter = RecordingWordCounter(result: 20)
        let state = makeState(wordCounter: wordCounter)
        state.inputText = "Measured draft"
        state.typingStartedAt = referenceDate.addingTimeInterval(-10)

        state.updateTypingStats(at: referenceDate)

        XCTAssertEqual(state.wordsPerMinute, 120, accuracy: 0.001)
        XCTAssertEqual(wordCounter.receivedTexts, ["Measured draft"])
    }

    func testLongPauseStartsANewWarmupSession() {
        let wordCounter = RecordingWordCounter(result: 20)
        let state = makeState(wordCounter: wordCounter)
        state.wordsPerMinute = 120
        state.typingStartedAt = referenceDate.addingTimeInterval(-20)
        state.lastTypingUpdate = referenceDate.addingTimeInterval(-16)
        state.lastTypingStatsRefresh = referenceDate.addingTimeInterval(-16)

        state.updateTypingStats(at: referenceDate)

        XCTAssertEqual(state.typingStartedAt, referenceDate)
        XCTAssertEqual(state.wordsPerMinute, 0)
        XCTAssertNil(state.lastTypingStatsRefresh)
        XCTAssertTrue(wordCounter.receivedTexts.isEmpty)
    }

    private func makeState(wordCounter: RecordingWordCounter) -> AppState {
        AppState(
            settings: RetypoSettings(),
            draftPersistence: RecordingDraftPersistence(),
            wordCounter: wordCounter,
            settingsPersistence: RecordingSettingsPersistence()
        )
    }
}
