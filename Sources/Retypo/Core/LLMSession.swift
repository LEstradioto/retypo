import Foundation

/// Owns the live LLM session: which models are loaded, whether a call is
/// in flight, and a generation counter that lets stale completions cancel
/// themselves when a newer call has started.
///
/// Holds the LLMRouter (the in-process port that fans out to provider
/// adapters). Knows nothing about editor state, persistence, or UI.
@MainActor
final class LLMSession: ObservableObject {
    @Published var isCorrecting = false
    @Published var isLoadingModels = false
    @Published var modelsByProvider: [ProviderKind: [ProviderModel]] = [:]

    let router = LLMRouter()

    /// Bumped every time a new call begins. A pending completion checks this
    /// against its captured generation and discards its result if the user
    /// kicked off a newer call meanwhile.
    var generation: Int = 0
}
