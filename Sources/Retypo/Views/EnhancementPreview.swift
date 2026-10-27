import Foundation

/// The mode editor's one-line answer to "what will this mode send?", plus a
/// warning when the selected provider cannot run it.
struct EnhancementPreview: Equatable {
    /// What the preview depends on; a change re-plans off the main thread.
    struct Key: Equatable {
        let sources: [ReferenceSource]
        let webSearch: Bool
        let provider: ProviderKind
    }

    let summary: String
    let warning: String?

    /// Reads the attached files, so it runs detached.
    static func make(_ enhancement: ModeEnhancement, provider: ProviderKind) async -> EnhancementPreview {
        let plan = await Task.detached { ReferencePlanner.plan(for: enhancement.sources) }.value
        return EnhancementPreview(plan: plan, webSearch: enhancement.webSearch, provider: provider)
    }

    init(plan: ReferencePlan, webSearch: Bool, provider: ProviderKind) {
        let parts = [Self.sourcesSummary(plan), webSearch ? "web search on" : nil].compactMap { $0 }
        summary = parts.isEmpty ? "Attach files or a folder, or turn on web search" : parts.joined(separator: " · ")
        if case .unavailable(let reason) = EnhancedRoute.pick(provider: provider, plan: plan, webSearch: webSearch) {
            warning = reason
        } else {
            warning = nil
        }
    }

    private static func sourcesSummary(_ plan: ReferencePlan) -> String? {
        switch plan {
        case .none: return nil
        case .inline(let documents) where documents.isEmpty: return "no readable text found"
        case .inline(let documents): return "sent in full · \(fileCount(documents.count)) · \(characterCount(documents))"
        case .onDemand(_, let count): return "searched on demand · \(fileCount(count))"
        }
    }

    private static func fileCount(_ count: Int) -> String {
        count == 1 ? "1 file" : "\(count.formatted()) files"
    }

    private static func characterCount(_ documents: [ReferenceDocument]) -> String {
        let characters = documents.reduce(0) { $0 + $1.text.count }
        return characters < 1_000 ? "\(characters) chars" : "\(characters / 1_000)k chars"
    }
}
