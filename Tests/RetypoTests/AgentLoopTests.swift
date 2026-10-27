import XCTest
@testable import Retypo

/// Plays back scripted turns and records what the loop sent.
final class ScriptedConversation: AgentConversation {
    private var turns: [AgentTurn]
    private(set) var receivedResults: [[ToolOutcome]] = []
    private(set) var lastRoundFlags: [Bool] = []
    let usage = TokenUsage(inputTokens: 42, outputTokens: 7)

    init(_ turns: [AgentTurn]) {
        self.turns = turns
    }

    func next(after results: [ToolOutcome], isLastRound: Bool) async throws -> AgentTurn {
        receivedResults.append(results)
        lastRoundFlags.append(isLastRound)
        return turns.isEmpty ? .toolCalls([]) : turns.removeFirst()
    }
}

/// Collects progress events from the loop.
actor ProgressRecorder {
    private(set) var events: [AgentProgress] = []
    func record(_ progress: AgentProgress) { events.append(progress) }
}

final class AgentLoopTests: XCTestCase {
    private var fixture: ReferenceFixture!

    override func setUpWithError() throws {
        fixture = try ReferenceFixture()
        try fixture.write("kb/policy.md", "Refunds within 7 days.")
    }

    override func tearDown() {
        fixture.remove()
    }

    private func loop(_ conversation: ScriptedConversation, recorder: ProgressRecorder, toolbox: ReferenceToolbox? = nil) -> AgentLoop {
        AgentLoop(conversation: conversation, toolbox: toolbox) { await recorder.record($0) }
    }

    func testAnImmediateAnswerEndsTheRun() async throws {
        let recorder = ProgressRecorder()
        let response = try await loop(ScriptedConversation([.answer("final text")]), recorder: recorder).run()
        XCTAssertEqual(response.text, "final text")
        XCTAssertEqual(response.usage, TokenUsage(inputTokens: 42, outputTokens: 7))
        let events = await recorder.events
        XCTAssertEqual(events, [.thinking])
    }

    func testToolResultsFeedTheNextRound() async throws {
        let search = ToolCall(id: "c1", name: "search_files", arguments: ["query": "refund"])
        let conversation = ScriptedConversation([.toolCalls([search]), .answer("rewritten")])
        let recorder = ProgressRecorder()
        let toolbox = ReferenceToolbox(roots: fixture.roots(["kb"]))
        let response = try await loop(conversation, recorder: recorder, toolbox: toolbox).run()
        XCTAssertEqual(response.text, "rewritten")
        XCTAssertEqual(conversation.receivedResults.last?.first?.callID, "c1")
        XCTAssertTrue(conversation.receivedResults.last?.first?.content.contains("kb/policy.md:1: Refunds") == true)
        let events = await recorder.events
        XCTAssertEqual(events, [.thinking, .searching("refund"), .thinking])
    }

    func testTheLastRoundIsFlaggedAndAnEndlessRunFails() async {
        let conversation = ScriptedConversation([])
        var looping = loop(conversation, recorder: ProgressRecorder())
        looping.rounds = 3
        do {
            _ = try await looping.run()
            XCTFail("a run that never answers must fail")
        } catch {
            XCTAssertEqual(conversation.lastRoundFlags, [false, false, true])
            XCTAssertTrue(error.localizedDescription.contains("3 rounds"))
        }
    }

    func testFileToolsWithoutSourcesReturnAnError() async throws {
        let read = ToolCall(id: "c1", name: "read_file", arguments: ["path": "x.md"])
        let conversation = ScriptedConversation([.toolCalls([read]), .answer("ok")])
        _ = try await loop(conversation, recorder: ProgressRecorder()).run()
        XCTAssertEqual(conversation.receivedResults.last?.first?.isError, true)
    }

    func testProgressLabelsNameWhatIsHappening() {
        XCTAssertEqual(AgentProgress(call: ToolCall(id: "1", name: "read_file", arguments: ["path": "kb/a.md"])).label, "Reading kb/a.md")
        XCTAssertEqual(AgentProgress(call: ToolCall(id: "1", name: "search_files", arguments: ["query": "glosa"])).label, "Searching “glosa”")
        XCTAssertEqual(AgentProgress.listing(nil).label, "Listing sources")
    }
}
