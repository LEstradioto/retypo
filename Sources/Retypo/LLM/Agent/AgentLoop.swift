import Foundation

/// What one provider round produced.
enum AgentTurn {
    case toolCalls([ToolCall])
    case answer(String)
}

/// A provider conversation that can run tool rounds. Each adapter owns its
/// transcript: Anthropic, for one, needs every content block (thinking
/// included) sent back unchanged with the tool results.
protocol AgentConversation: AnyObject {
    /// `results` answer the previous turn's tool calls and are empty on the
    /// first call. `isLastRound` tells the model to answer without more tools.
    func next(after results: [ToolOutcome], isLastRound: Bool) async throws -> AgentTurn
    /// Summed over every request of the run.
    var usage: TokenUsage { get }
}

/// What the status line shows while an enhanced mode works.
enum AgentProgress: Equatable {
    case thinking
    case listing(String?)
    case searching(String)
    case reading(String)

    init(call: ToolCall) {
        switch call.name {
        case ReferenceTools.search.name: self = .searching(call.string("query") ?? "")
        case ReferenceTools.read.name: self = .reading(call.string("path") ?? "")
        default: self = .listing(call.string("path"))
        }
    }

    var label: String {
        switch self {
        case .thinking: "Thinking…"
        case .listing(let path): path.map { "Listing \($0)" } ?? "Listing sources"
        case .searching(let query): "Searching “\(query)”"
        case .reading(let path): "Reading \(path)"
        }
    }
}

/// The research loop of an enhanced mode. Deliberately smaller than a
/// coding harness: read-only tools, a fixed number of rounds, and the
/// final text as the only output.
struct AgentLoop {
    /// Rounds are model requests. Seven tool rounds cover "find the policy,
    /// read it, rewrite"; the eighth has to answer.
    static let defaultRounds = 8

    let conversation: AgentConversation
    /// nil for a web-only mode: no local tools are offered then.
    let toolbox: ReferenceToolbox?
    var rounds = defaultRounds
    let onProgress: (AgentProgress) async -> Void

    func run() async throws -> LLMResponse {
        var results: [ToolOutcome] = []
        for round in 1...rounds {
            await onProgress(.thinking)
            switch try await conversation.next(after: results, isLastRound: round == rounds) {
            case .answer(let text): return LLMResponse(text: text, usage: conversation.usage)
            case .toolCalls(let calls): results = await execute(calls)
            }
        }
        throw LLMError.researchUnfinished(rounds)
    }

    /// One at a time, in the order asked: file reads are fast, and the
    /// status line can say what each one is.
    private func execute(_ calls: [ToolCall]) async -> [ToolOutcome] {
        var outcomes: [ToolOutcome] = []
        for call in calls {
            await onProgress(AgentProgress(call: call))
            outcomes.append(toolbox?.run(call) ?? Self.noSourcesOutcome(for: call))
        }
        return outcomes
    }

    private static func noSourcesOutcome(for call: ToolCall) -> ToolOutcome {
        ToolOutcome(callID: call.id, content: "This mode has no attached files to read.", isError: true)
    }
}
