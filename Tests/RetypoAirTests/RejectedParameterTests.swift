import XCTest
@testable import RetypoAir

/// The bodies here are verbatim captures from the live APIs (2026-08-05).
final class RejectedParameterTests: XCTestCase {
    func testAnthropicQuotesTheParameterInsideTheMessage() {
        let body = #"{"type":"error","error":{"type":"invalid_request_error","message":"`temperature` is deprecated for this model."},"request_id":"req_1"}"#
        XCTAssertEqual(RejectedParameter.name(in: body), "temperature")
    }

    func testAnthropicNestedFieldReducesToItsTopLevelKey() {
        let body = #"{"type":"error","error":{"type":"invalid_request_error","message":"\"thinking.type.disabled\" is not supported for this model."}}"#
        XCTAssertEqual(RejectedParameter.name(in: body), "thinking")
    }

    func testOpenAIParamFieldWins() {
        let body = #"{"error":{"message":"Unsupported parameter: 'temperature' is not supported with this model.","type":"invalid_request_error","param":"temperature","code":null}}"#
        XCTAssertEqual(RejectedParameter.name(in: body), "temperature")
    }

    func testOpenAINestedParamReducesToItsTopLevelKey() {
        let body = #"{"error":{"message":"Unsupported parameter: 'reasoning.effort' is not supported with this model.","param":"reasoning.effort","code":"unsupported_parameter"}}"#
        XCTAssertEqual(RejectedParameter.name(in: body), "reasoning")
    }

    func testErrorsWithoutAQuotedParameterYieldNil() {
        let body = #"{"error":{"message":"Rate limit reached for requests"}}"#
        XCTAssertNil(RejectedParameter.name(in: body))
    }

    func testNonJSONBodyYieldsNil() {
        XCTAssertNil(RejectedParameter.name(in: "<html>502 Bad Gateway</html>"))
    }

    func testMemoryIsScopedPerProviderAndModel() async {
        let memory = RejectedParameterMemory()
        await memory.remember("temperature", provider: .anthropic, model: "claude-opus-5")

        let remembered = await memory.rejected(provider: .anthropic, model: "claude-opus-5")
        XCTAssertEqual(remembered, ["temperature"])
        let otherModel = await memory.rejected(provider: .anthropic, model: "claude-haiku-4-5")
        XCTAssertTrue(otherModel.isEmpty)
        let otherProvider = await memory.rejected(provider: .openai, model: "claude-opus-5")
        XCTAssertTrue(otherProvider.isEmpty)
    }
}
