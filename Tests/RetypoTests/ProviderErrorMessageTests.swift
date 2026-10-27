import XCTest
@testable import Retypo

final class ProviderErrorMessageTests: XCTestCase {
    /// The old formatting showed `{"type":"error","error":{"type":"invalid_…`
    /// and truncated before the sentence that names the problem.
    func testExtractsTheHumanSentenceFromAnAnthropicError() {
        let body = #"{"type":"error","error":{"type":"invalid_request_error","message":"`temperature` is deprecated for this model."},"request_id":"req_1"}"#
        XCTAssertEqual(ProviderErrorMessage.summary(body), "`temperature` is deprecated for this model.")
    }

    func testExtractsTheHumanSentenceFromAnOpenAIError() {
        let body = #"{"error":{"message":"Unsupported parameter: 'temperature' is not supported with this model.","param":"temperature"}}"#
        XCTAssertEqual(ProviderErrorMessage.summary(body), "Unsupported parameter: 'temperature' is not supported with this model.")
    }

    func testFallsBackToABareMessageField() {
        XCTAssertEqual(ProviderErrorMessage.summary(#"{"message":"No endpoints found"}"#), "No endpoints found")
    }

    func testFallsBackToTheRawBodyWhenItIsNotJSON() {
        XCTAssertEqual(ProviderErrorMessage.summary("  502 Bad Gateway  "), "502 Bad Gateway")
    }

    func testCollapsesNewlinesAndTruncatesLongText() {
        let summary = ProviderErrorMessage.summary("line one\nline two", limit: 12)
        XCTAssertEqual(summary, "line one lin…")
    }

    func testLLMErrorDescriptionCarriesTheProviderSentence() {
        let body = #"{"error":{"message":"model not found"}}"#
        let description = LLMError.badStatus(404, body).errorDescription
        XCTAssertEqual(description, "API error 404: model not found")
    }

    func testEmptyCompletionExplainsItself() {
        let description = LLMError.emptyCompletion("spent the whole token budget on reasoning").errorDescription
        XCTAssertEqual(description, "Model returned no text (spent the whole token budget on reasoning)")
    }
}
