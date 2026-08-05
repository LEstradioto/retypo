import Foundation

extension AppState {
    /// Every provider failure lands here. The footer only has room for one
    /// truncated line, so the full text is also kept for the tooltip, for the
    /// click-to-copy action, and appended to `~/.retypo-air/import-debug.log`.
    func report(_ error: Error, while activity: String) {
        let message = error.localizedDescription
        status = message
        lastErrorDetail = "\(activity) · \(providerContext()) · \(message)"
        DebugLog.log(lastErrorDetail ?? message)
    }

    /// Cleared when a new run starts so a stale error can't outlive it.
    func clearLastError() {
        lastErrorDetail = nil
    }

    /// The status line truncates; a click puts the whole thing on the clipboard.
    func copyLastError() {
        guard let detail = lastErrorDetail else { return }
        ClipboardService.copy(detail)
        status = "Error copied to clipboard"
    }

    private func providerContext() -> String {
        "\(settings.provider.displayName)/\(selectedModel ?? "no model")"
    }
}
