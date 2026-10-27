import Foundation

extension AppState {
    func applyResult(_ outcome: ActionOutcome) {
        pushEditorUndoSnapshot()
        let text = outcome.text
        correctedText = text
        outputText = text
        diffText = DiffService.compactDiff(original: outcome.original, corrected: text)
        wordsChangedLast = InlineDiffService.changedWordCount(original: outcome.original, corrected: text)
        let costUSD = cost.recordUsage(provider: settings.provider, model: selectedModel ?? "", usage: outcome.response.usage)
        appendHistory(HistoryDraft(original: outcome.original, output: text, diff: diffText, action: outcome.action, instruction: outcome.instruction, usage: outcome.response.usage, costUSD: costUSD))
        cost.appendLedgerEntry(provider: settings.provider, model: selectedModel ?? "", usage: outcome.response.usage, costUSD: costUSD)
        if settings.autoCopy {
            copyOutput(text)
        } else {
            status = outcome.changed ? "Done" : "No changes"
        }
        applyInlineSubstitution(original: outcome.original, text: text)
    }

    private func applyInlineSubstitution(original: String, text: String) {
        inlineHighlightRanges = InlineDiffService.changedRanges(original: original, corrected: text)
        suppressNextInputChange = true
        inputText = text
        draftPersistence.save(inputText)
    }

    func appendCandidate(_ outcome: ActionOutcome) {
        let costUSD = cost.computeCost(provider: settings.provider, model: selectedModel ?? "", usage: outcome.response.usage)
        let diff = DiffService.compactDiff(original: outcome.original, corrected: outcome.text)
        candidateResults.append(CandidateResult(action: outcome.action, output: outcome.text, diff: diff, usage: outcome.response.usage, costUSD: costUSD))
        appendHistory(HistoryDraft(original: outcome.original, output: outcome.text, diff: diff, action: outcome.action, instruction: outcome.instruction, usage: outcome.response.usage, costUSD: costUSD))
        cost.appendLedgerEntry(provider: settings.provider, model: selectedModel ?? "", usage: outcome.response.usage, costUSD: costUSD)
    }

    func appendHistory(_ draft: HistoryDraft) {
        guard let model = selectedModel else { return }
        let entry = HistoryEntry(
            provider: settings.provider, model: model,
            actionID: draft.action.id, actionTitle: draft.action.title,
            instruction: draft.instruction,
            input: draft.original, output: draft.output, diff: draft.diff,
            usage: draft.usage, costUSD: draft.costUSD
        )
        history.insert(entry, at: 0)
        history = Array(history.prefix(max(1, settings.historyLimit)))
        HistoryStore.save(history, limit: settings.historyLimit)
    }

    func parseCorrection(_ text: String) -> (corrected: String, changed: Bool, confidence: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end {
            jsonText = String(trimmed[start...end])
        } else {
            jsonText = trimmed
        }
        guard let data = jsonText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let corrected = obj["corrected"] as? String else { return nil }
        let changed = obj["changed"] as? Bool ?? (corrected != inputText)
        let confidence = obj["confidence"] as? Double ?? 0.5
        return (corrected, changed, confidence)
    }
}
