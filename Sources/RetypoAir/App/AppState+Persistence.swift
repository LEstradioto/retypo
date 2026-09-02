import Foundation
import AppKit

extension AppState {
    func saveSettings() {
        settingsPersistence.save(settings)
    }

    func saveModes() {
        EditActionStore.save(actions)
    }

    // Pricing forwarding (CostTracker owns the data; views observe AppState).
    func mergePricingDefaults(for provider: ProviderKind, models: [ProviderModel]) {
        cost.mergePricingDefaults(for: provider, models: models)
    }

    func pricingBindingValue(for provider: ProviderKind, model: String) -> ModelPricing {
        cost.pricingBindingValue(for: provider, model: model)
    }

    func setPricing(_ value: ModelPricing, provider: ProviderKind, model: String) {
        cost.setPricing(value, provider: provider, model: model)
    }

    func updatePanelFrame(_ frame: NSRect) {
        let panelFrame = PanelFrame(frame)
        guard panelFrame != settings.panelFrame else { return }
        settings.panelFrame = panelFrame
        panelFrameSavePending = true
        panelFrameDebouncer.schedule(milliseconds: 300) { [weak self] in
            self?.persistPendingPanelFrame()
        }
    }

    func flushPendingPanelFrame() {
        panelFrameDebouncer.cancel()
        persistPendingPanelFrame()
    }

    private func persistPendingPanelFrame() {
        guard panelFrameSavePending else { return }
        panelFrameSavePending = false
        saveSettings()
    }

    func scheduleDraftSnapshot() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftHistoryDebouncer.schedule(milliseconds: 1_500) { [weak self] in
            guard let self else { return }
            self.saveDraftSnapshotNow()
        }
    }

    func saveDraftSnapshotNow() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return }
        guard draftSnapshots.first?.text != text else { return }
        draftSnapshots.insert(DraftSnapshot(text: text), at: 0)
        draftSnapshots = Array(draftSnapshots.prefix(20))
        DraftSnapshotStore.save(draftSnapshots)
    }

    /// Monkeytype-style WPM: hide for the first ~5s warm-up window, reset
    /// the session if the user paused longer than 15s, otherwise the simple
    /// `words / elapsed_minutes` average since session start. The expensive
    /// localized count refreshes at 2 Hz while timestamp tracking stays per-key.
    func updateTypingStats(at now: Date = Date()) {
        updateTypingSession(at: now)
        guard let started = typingStartedAt else { return }
        let elapsed = now.timeIntervalSince(started)
        guard elapsed >= Self.typingWarmupSeconds else {
            if wordsPerMinute != 0 { wordsPerMinute = 0 }
            return
        }
        guard shouldRefreshTypingStats(at: now) else { return }
        lastTypingStatsRefresh = now
        wordsPerMinute = Double(wordCounter.countWords(in: inputText)) / (elapsed / 60)
    }

    static let typingWarmupSeconds: TimeInterval = 5
    static let typingPauseResetSeconds: TimeInterval = 15
    static let typingStatsRefreshSeconds: TimeInterval = 0.5

    private func updateTypingSession(at now: Date) {
        resetTypingSessionAfterPause(at: now)
        if typingStartedAt == nil { typingStartedAt = now }
        lastTypingUpdate = now
    }

    private func resetTypingSessionAfterPause(at now: Date) {
        guard let lastTypingUpdate else { return }
        guard now.timeIntervalSince(lastTypingUpdate) > Self.typingPauseResetSeconds else { return }
        typingStartedAt = now
        lastTypingStatsRefresh = nil
    }

    private func shouldRefreshTypingStats(at now: Date) -> Bool {
        guard let lastTypingStatsRefresh else { return true }
        return now.timeIntervalSince(lastTypingStatsRefresh) >= Self.typingStatsRefreshSeconds
    }
}
