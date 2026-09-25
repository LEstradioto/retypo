import XCTest
@testable import RetypoAir

/// Named fake for the engine seam: records requests, returns a canned
/// result or throws a canned error.
final class FakeLiveTranslator: LiveTranslator {
    var resultText = "Olá"
    var error: Error?
    private(set) var receivedTexts: [String] = []

    @MainActor
    func translate(_ text: String, target: TargetLanguage) async throws -> LiveTranslationResult {
        receivedTexts.append(text)
        if let error { throw error }
        return LiveTranslationResult(text: resultText, usage: .zero)
    }
}

@MainActor
final class LiveTranslationTests: XCTestCase {
    private func makeState() -> AppState {
        AppState(
            settings: RetypoSettings(),
            draftPersistence: RecordingDraftPersistence(),
            settingsPersistence: RecordingSettingsPersistence()
        )
    }

    func testRunLiveTranslationWritesResult() async {
        let state = makeState()
        state.liveTranslationGeneration = 1
        let fake = FakeLiveTranslator()
        fake.resultText = "Olá mundo"

        await state.runLiveTranslation("Hello world", generation: 1, using: fake)

        XCTAssertEqual(state.liveTranslationText, "Olá mundo")
        XCTAssertNil(state.liveTranslationError)
        XCTAssertEqual(fake.receivedTexts, ["Hello world"])
    }

    func testStaleLiveTranslationIsDropped() async {
        let state = makeState()
        let fake = FakeLiveTranslator()
        fake.resultText = "Late"
        state.liveTranslationGeneration = 5

        await state.runLiveTranslation("Hello", generation: 4, using: fake)

        XCTAssertEqual(state.liveTranslationText, "")
    }

    func testEmptyInputClearsTranslation() async {
        let state = makeState()
        state.liveTranslationGeneration = 1
        state.liveTranslationText = "Stale"
        let fake = FakeLiveTranslator()

        await state.runLiveTranslation("   ", generation: 1, using: fake)

        XCTAssertEqual(state.liveTranslationText, "")
        XCTAssertEqual(fake.receivedTexts, [])
    }

    func testTranslationFailureSurfacesError() async {
        let state = makeState()
        state.liveTranslationGeneration = 1
        let fake = FakeLiveTranslator()
        fake.error = LiveTranslationError.noModel

        await state.runLiveTranslation("Hello", generation: 1, using: fake)

        XCTAssertTrue(state.liveTranslationError?.contains("model") == true, state.liveTranslationError ?? "nil")
        XCTAssertEqual(state.liveTranslationText, "")
    }

    func testScheduleIsNoopWhenFeatureDisabled() async {
        let state = makeState()
        state.settings.liveTranslationEnabled = false

        state.scheduleLiveTranslation()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(state.liveTranslationText, "")
        XCTAssertNil(state.liveTranslationTask)
    }

    func testToggleOffClearsTranslation() {
        let state = makeState()
        state.settings.liveTranslationEnabled = true
        state.liveTranslationText = "Olá"

        state.toggleLiveTranslation()

        XCTAssertFalse(state.settings.liveTranslationEnabled)
        XCTAssertEqual(state.liveTranslationText, "")
    }

    func testFallbackTranslatorRetriesWithFallback() async throws {
        let primary = FakeLiveTranslator()
        primary.error = LiveTranslationError.noModel
        let fallback = FakeLiveTranslator()
        fallback.resultText = "from fallback"

        let result = try await FallbackTranslator(primary: primary, fallback: fallback)
            .translate("Hi", target: TargetLanguage.named("en"))

        XCTAssertEqual(result.text, "from fallback")
    }

    func testLLMRequestFramesTextAndNamesTargetLanguage() {
        let translator = LLMTranslator(
            router: LLMRouter(),
            provider: RetypoSettings().provider,
            model: "some-model",
            preamble: ""
        )
        let request = translator.request(text: "Hi", target: TargetLanguage.named("pt-BR"))
        XCTAssertTrue(request.system.contains("Translate the text to natural Portuguese (BR)"))
        XCTAssertTrue(request.system.contains("Return only the translated text"))
        XCTAssertTrue(request.user.hasPrefix("Text to edit:"))
    }

    func testLLMTranslatorWithoutModelThrows() async {
        let translator = LLMTranslator(router: LLMRouter(), provider: .anthropic, model: "", preamble: "")
        do {
            _ = try await translator.translate("Hi", target: TargetLanguage.named("en"))
            XCTFail("expected noModel")
        } catch {
            XCTAssertEqual(error as? LiveTranslationError, .noModel)
        }
    }

    func testLiveTranslationSettingsRoundTripDefaults() throws {
        let decoded = try JSONDecoder().decode(RetypoSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(decoded.liveTranslationEnabled)
        XCTAssertEqual(decoded.liveTranslationTarget, "pt-BR")
        XCTAssertEqual(decoded.liveTranslationEngine, .auto)
    }
}
