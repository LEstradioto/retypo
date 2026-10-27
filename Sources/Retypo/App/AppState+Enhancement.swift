import Foundation

extension AppState {
    /// Plain modes make one request; enhanced ones research first. Progress
    /// lands in the status line while `generation` is still the current run.
    func complete(_ request: LLMRequest, for action: EditAction, generation: Int) async throws -> LLMResponse {
        guard action.isEnhanced, let enhancement = action.enhancement else {
            return try await llm.router.complete(request)
        }
        return try await llm.router.completeEnhanced(request, enhancement: enhancement) { [weak self] progress in
            await self?.showResearchProgress(progress, mode: action.title, generation: generation)
        }
    }

    func showResearchProgress(_ progress: AgentProgress, mode: String, generation: Int) {
        guard generation == llm.generation, llm.isCorrecting else { return }
        status = "\(mode) · \(progress.label)"
    }

    func setEnhanced(_ enabled: Bool, modeID: String) {
        updateEnhancement(of: modeID) { enhancement in
            var updated = enhancement ?? ModeEnhancement()
            updated.isOn = enabled
            enhancement = updated
        }
    }

    func attachReferences(_ urls: [URL], modeID: String) {
        let sources = urls.filter(\.isFileURL).map(ReferenceSource.init(url:))
        guard !sources.isEmpty else { return }
        updateEnhancement(of: modeID) { enhancement in
            var updated = enhancement ?? ModeEnhancement()
            updated.attach(sources)
            enhancement = updated
        }
    }

    func detachReference(_ source: ReferenceSource, modeID: String) {
        updateEnhancement(of: modeID) { enhancement in
            enhancement?.sources.removeAll { $0 == source }
        }
    }

    func setWebSearch(_ enabled: Bool, modeID: String) {
        updateEnhancement(of: modeID) { enhancement in
            var updated = enhancement ?? ModeEnhancement()
            updated.webSearch = enabled
            enhancement = updated
        }
    }

    private func updateEnhancement(of modeID: String, _ change: (inout ModeEnhancement?) -> Void) {
        guard let index = actions.firstIndex(where: { $0.id == modeID }), actions[index].canBeEnhanced else { return }
        change(&actions[index].enhancement)
        saveModes()
    }
}
