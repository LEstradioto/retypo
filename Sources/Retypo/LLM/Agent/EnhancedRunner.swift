import Foundation

/// How an enhanced run reaches its provider.
enum EnhancedRoute: Equatable {
    /// Documents inline (or none) and no web search: one plain request,
    /// which every provider can take.
    case singleRequest
    /// Large sources or web search through the Messages API tool loop.
    case anthropicTools
    /// Claude Code and Codex research with their own tools.
    case cliTools
    case unavailable(String)

    static func pick(provider: ProviderKind, plan: ReferencePlan, webSearch: Bool) -> EnhancedRoute {
        guard plan.needsTools || webSearch else { return .singleRequest }
        if provider == .codex, webSearch { return .unavailable(codexWebSearchReason) }
        if provider.usesLocalCLI { return .cliTools }
        if provider == .anthropic { return .anthropicTools }
        return .unavailable(unavailableReason(provider, webSearch: webSearch))
    }

    /// Codex's read-only sandbox reads any file the user can; live search
    /// would hand a planted instruction a way to send one out.
    static let codexWebSearchReason = "Web search is off on Codex: its sandbox can read any of your files, and search would give a planted instruction a way out. Use Anthropic or Claude Code"

    private static func unavailableReason(_ provider: ProviderKind, webSearch: Bool) -> String {
        let need = webSearch ? "Web search" : "Sources over \(ReferencePlanner.inlineCharacterBudget / 1_000)k characters"
        let providers = webSearch ? "Anthropic or Claude Code" : "Anthropic, Claude Code or Codex"
        return "\(need) needs \(providers); \(provider.displayName) only takes small sources sent whole"
    }
}

/// Runs an enhanced mode: sizes up the attached sources, writes the prompt,
/// then sends it the way the selected provider can take it.
struct EnhancedRunner {
    let router: LLMRouter
    /// The Anthropic transport, shared with the plain provider so a rejected
    /// parameter is learned once.
    let anthropic: ProviderSending

    func run(_ request: LLMRequest, enhancement: ModeEnhancement, onProgress: @escaping (AgentProgress) async -> Void) async throws -> LLMResponse {
        let plan = await Task.detached { ReferencePlanner.plan(for: enhancement.sources) }.value
        let brief = ResearchBrief(plan: plan, webSearch: enhancement.webSearch)
        switch EnhancedRoute.pick(provider: request.provider, plan: plan, webSearch: enhancement.webSearch) {
        case .singleRequest: return try await router.complete(Self.prompted(request, brief))
        case .cliTools: return try await cliRun(request, brief: brief)
        case .anthropicTools: return try await anthropicLoop(Self.prompted(request, brief), brief: brief, onProgress: onProgress)
        case .unavailable(let reason): throw LLMError.enhancedUnavailable(reason)
        }
    }

    private static func prompted(_ request: LLMRequest, _ brief: ResearchBrief) -> LLMRequest {
        var request = request
        request.system = EnhancedPrompt.system(base: request.system, brief: brief)
        return request
    }

    /// Claude Code and Codex research with their own tools, started in a
    /// per-run folder that is removed afterwards.
    private func cliRun(_ request: LLMRequest, brief: ResearchBrief) async throws -> LLMResponse {
        let workspace = try CLIResearchWorkspace(plan: brief.plan, webSearch: brief.webSearch)
        defer { workspace.remove() }
        var cliBrief = brief
        cliBrief.cliPaths = workspace.paths
        var request = Self.prompted(request, cliBrief)
        request.research = workspace.access
        return try await router.complete(request)
    }

    private func anthropicLoop(_ request: LLMRequest, brief: ResearchBrief, onProgress: @escaping (AgentProgress) async -> Void) async throws -> LLMResponse {
        guard let apiKey = APIKeyStore.apiKey(for: .anthropic) else { throw LLMError.missingAPIKey(.anthropic) }
        var toolbox: ReferenceToolbox?
        if case .onDemand(let roots, _) = brief.plan { toolbox = ReferenceToolbox(roots: roots) }
        let setup = AnthropicResearchSetup(
            model: request.model, system: request.system, user: request.user,
            tools: toolbox == nil ? [] : ReferenceTools.all, webSearch: brief.webSearch
        )
        let conversation = AnthropicConversation(setup: setup, apiKey: apiKey, sender: anthropic)
        return try await AgentLoop(conversation: conversation, toolbox: toolbox, onProgress: onProgress).run()
    }
}
