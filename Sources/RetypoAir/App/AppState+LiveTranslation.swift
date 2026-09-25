import Foundation

extension AppState {
    /// Debounced live translation of the input text. Typing cancels the
    /// pending run; stale responses are dropped via the generation counter.
    func scheduleLiveTranslation() {
        guard settings.liveTranslationEnabled else { return }
        liveTranslationGeneration += 1
        let generation = liveTranslationGeneration
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranslationTask?.cancel()
        liveTranslationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, generation == self.liveTranslationGeneration else { return }
            await self.runLiveTranslation(text, generation: generation, using: self.liveTranslator())
        }
    }

    func runLiveTranslation(_ text: String, generation: Int, using translator: LiveTranslator) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            applyLiveTranslation("", generation: generation)
            return
        }
        liveTranslationBusy = true
        defer { if generation == liveTranslationGeneration { liveTranslationBusy = false } }
        let target = TargetLanguage.named(settings.liveTranslationTarget)
        do {
            let result = try await translator.translate(trimmed, target: target)
            applyLiveTranslation(result.text, generation: generation)
            cost.recordUsage(provider: settings.provider, model: selectedModel ?? "", usage: result.usage)
        } catch {
            guard generation == liveTranslationGeneration else { return }
            liveTranslationError = error.localizedDescription
        }
    }

    private func applyLiveTranslation(_ text: String, generation: Int) {
        guard generation == liveTranslationGeneration else { return }
        liveTranslationText = text
        liveTranslationError = nil
    }

    /// Builds the engine for the settings pick. Auto pairs Apple (macOS 15+)
    /// with the LLM as fallback; forced Apple degrades to the LLM on older
    /// macOS so the card never goes dead.
    func liveTranslator() -> LiveTranslator {
        switch settings.liveTranslationEngine {
        case .llm:
            return llmTranslator()
        case .apple:
            return appleTranslator() ?? llmTranslator()
        case .auto:
            guard let apple = appleTranslator() else { return llmTranslator() }
            return FallbackTranslator(primary: apple, fallback: llmTranslator())
        }
    }

    private func appleTranslator() -> LiveTranslator? {
        if #available(macOS 15.0, *) { return AppleTranslationEngine() }
        return nil
    }

    private func llmTranslator() -> LiveTranslator {
        LLMTranslator(
            router: llm.router,
            provider: settings.provider,
            model: selectedModel ?? "",
            preamble: settings.systemPreamble
        )
    }

    func setLiveTranslationTarget(_ code: String) {
        settings.liveTranslationTarget = code
        saveSettings()
        scheduleLiveTranslation()
    }

    func setLiveTranslationEngine(_ engine: LiveTranslationEngine) {
        settings.liveTranslationEngine = engine
        saveSettings()
        scheduleLiveTranslation()
    }

    func toggleLiveTranslation() {
        settings.liveTranslationEnabled.toggle()
        saveSettings()
        if settings.liveTranslationEnabled {
            scheduleLiveTranslation()
        } else {
            liveTranslationTask?.cancel()
            liveTranslationText = ""
            liveTranslationError = nil
        }
    }
}
