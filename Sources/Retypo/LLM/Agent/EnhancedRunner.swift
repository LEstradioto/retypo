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
        if provider.usesLocalCLI { return .cliTools }
        if provider == .anthropic { return .anthropicTools }
        return .unavailable(unavailableReason(provider, webSearch: webSearch))
    }

    private static func unavailableReason(_ provider: ProviderKind, webSearch: Bool) -> String {
        let need = webSearch ? "Web search" : "Sources over \(ReferencePlanner.inlineCharacterBudget / 1_000)k characters"
        return "\(need) needs Anthropic, Claude Code or Codex; \(provider.displayName) only takes small sources sent whole"
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
        let route = EnhancedRoute.pick(provider: request.provider, plan: plan, webSearch: enhancement.webSearch)
        let brief = ResearchBrief(plan: plan, webSearch: enhancement.webSearch, readsWithOwnTools: route == .cliTools)
        var request = request
        request.system = EnhancedPrompt.system(base: request.system, brief: brief)
        switch route {
        case .singleRequest: return try await router.complete(request)
        case .cliTools:
            request.research = CLIResearchAccess(plan: plan, webSearch: enhancement.webSearch)
            return try await router.complete(request)
        case .anthropicTools: return try await anthropicLoop(request, brief: brief, onProgress: onProgress)
        case .unavailable(let reason): throw LLMError.enhancedUnavailable(reason)
        }
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
