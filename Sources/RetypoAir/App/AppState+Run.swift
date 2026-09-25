import Foundation

extension AppState {
    struct ActionOutcome {
        let text: String
        let original: String
        let changed: Bool
        let response: LLMResponse
        let action: EditAction
        let instruction: String
    }

    struct HistoryDraft {
        let original: String
        let output: String
        let diff: String
        let action: EditAction
        let instruction: String
        let usage: TokenUsage
        let costUSD: Double?
    }

    func runCurrentAction(source: String = "manual") async {
        await runAction(currentAction, source: source)
    }

    private func correctAndMaybeCopy(_ action: EditAction, source: String) async {
        guard let context = startCorrection(source: source) else { return }
        let request = correctionRequest(action: action, model: context.model, original: context.original)
        do {
            let response = try await llm.router.complete(request)
            guard context.generation == llm.generation else { return }
            let parsed = parseCorrection(response.text) ?? (response.text.trimmingCharacters(in: .whitespacesAndNewlines), true, 0.5)
            applyResult(ActionOutcome(text: parsed.corrected, original: context.original, changed: parsed.changed, response: response, action: action, instruction: request.system))
        } catch {
            guard context.generation == llm.generation else { return }
            report(error, while: "Correct")
        }
        finishEditingRun()
    }

    /// A run finished (applied or failed). Clearing the flag first matters:
    /// the mode result landed in the editor while translation was holding
    /// back, so the card must now catch up to the applied text.
    private func finishEditingRun() {
        llm.isCorrecting = false
        scheduleLiveTranslation()
    }

    func runAction(_ action: EditAction, source: String = "manual") async {
        if action.id == "correct" {
            await correctAndMaybeCopy(action, source: source)
            return
        }
        if action.id == EditAction.freeformID {
            // Freeform always routes through the prompt panel — let the user
            // type/edit the instruction before the request fires. Bump the
            // show-ID so the text field re-focuses each time.
            freeformPromptShowID &+= 1
            host?.setFreeformPromptVisible(true)
            return
        }
        await performEditAction(action, source: source)
    }

    /// The inner runner used by `runAction` (for non-freeform actions) and by
    /// `confirmFreeformPrompt` (after the user has typed an instruction).
    func performEditAction(_ action: EditAction, source: String) async {
        guard let instruction = resolvedInstruction(for: action) else {
            status = "Type a Freeform instruction first"
            return
        }
        guard let context = startEditAction(action, source: source) else { return }
        do {
            let response = try await llm.router.complete(editRequest(instruction: instruction, model: context.model, original: context.original))
            guard context.generation == llm.generation else { return }
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            applyResult(ActionOutcome(text: text, original: context.original, changed: text != context.original, response: response, action: action, instruction: instruction))
        } catch {
            guard context.generation == llm.generation else { return }
            report(error, while: action.title)
        }
        finishEditingRun()
    }

    func confirmFreeformPrompt() {
        host?.setFreeformPromptVisible(false)
        let action = currentAction
        Task {
            await performEditAction(action, source: "freeform")
            // After Freeform finishes, drop the candidates panel + cards so
            // the next Cmd+D opens fresh in launcher mode. The result still
            // lives in the main editor's output.
            candidateResults = []
            selectedCandidateIndex = 0
            host?.setCandidatesVisible(false)
        }
    }

    func cancelFreeformPrompt() {
        host?.setFreeformPromptVisible(false)
    }

    /// Resolve the system instruction for an action, returning nil when the
    /// Freeform mode has no user-typed instruction yet.
    func resolvedInstruction(for action: EditAction) -> String? {
        if action.id == EditAction.freeformID {
            let trimmed = freeformInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return action.instruction
    }

    func runAllEnabledModes() async {
        guard let model = selectedModel else { status = "Choose a model before running all"; return }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }
        llm.isCorrecting = true
        status = "Running \(enabledActions.count) modes"
        candidateResults = []
        setCandidateOverlayVisible(true)
        selectedCandidateIndex = 0
        for action in enabledActions {
            await runOneCandidate(action, model: model, original: original)
        }
        if !candidateResults.isEmpty { selectCandidate(at: 0) }
        llm.isCorrecting = false
    }

    private func runOneCandidate(_ action: EditAction, model: String, original: String) async {
        do {
            if action.id == "correct" {
                let request = correctionRequest(action: action, model: model, original: original)
                let response = try await llm.router.complete(request)
                let parsed = parseCorrection(response.text) ?? (response.text.trimmingCharacters(in: .whitespacesAndNewlines), true, 0.5)
                appendCandidate(ActionOutcome(text: parsed.corrected, original: original, changed: parsed.changed, response: response, action: action, instruction: request.system))
            } else {
                guard let instruction = resolvedInstruction(for: action) else { return }
                let response = try await llm.router.complete(editRequest(instruction: instruction, model: model, original: original))
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                appendCandidate(ActionOutcome(text: text, original: original, changed: text != original, response: response, action: action, instruction: instruction))
            }
        } catch {
            report(error, while: action.title)
        }
    }

    private struct ActionContext {
        let model: String
        let original: String
        let generation: Int
    }

    private func startCorrection(source: String) -> ActionContext? {
        guard let context = beginAction(statusAuto: "Auto correcting", statusManual: "Correcting", source: source) else {
            if selectedModel == nil { status = "Choose a model before correction" }
            return nil
        }
        return context
    }

    private func startEditAction(_ action: EditAction, source: String) -> ActionContext? {
        let auto = "Auto \(action.title.lowercased())"
        let manual = "Running \(action.title)"
        guard let context = beginAction(statusAuto: auto, statusManual: manual, source: source) else {
            if selectedModel == nil { status = "Choose a model before editing" }
            return nil
        }
        return context
    }

    private func beginAction(statusAuto: String, statusManual: String, source: String) -> ActionContext? {
        guard let model = selectedModel else { return nil }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return nil }
        llm.generation += 1
        llm.isCorrecting = true
        clearLastError()
        status = source == "auto" ? statusAuto : statusManual
        return ActionContext(model: model, original: original, generation: llm.generation)
    }

    private func correctionRequest(action: EditAction, model: String, original: String) -> LLMRequest {
        LLMRequest(
            provider: settings.provider,
            model: model,
            system: PromptTemplates.correctionSystem(instruction: action.instruction, preamble: settings.systemPreamble),
            user: PromptTemplates.userMessage(original),
            maxTokens: max(512, min(4_000, original.count * 2)),
            temperature: 0
        )
    }

    private func editRequest(instruction: String, model: String, original: String) -> LLMRequest {
        LLMRequest(
            provider: settings.provider,
            model: model,
            system: PromptTemplates.actionSystem(instruction: instruction, preamble: settings.systemPreamble),
            user: PromptTemplates.userMessage(original),
            maxTokens: max(800, min(5_000, original.count * 2)),
            temperature: 0.2
        )
    }
}
