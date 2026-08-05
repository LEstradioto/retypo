import XCTest
@testable import RetypoAir

final class ProviderPostTests: XCTestCase {
    private func post(body: [String: Any]) -> ProviderPost {
        ProviderPost(
            url: URL(staticString: "https://example.test/v1/messages"),
            headers: ["x-api-key": "k"],
            body: body,
            optionalKeys: ["temperature"]
        )
    }

    func testDroppingRemovesOnlyTheNamedKeys() {
        let dropped = post(body: ["model": "m", "temperature": 0.0]).dropping(["temperature"])
        XCTAssertEqual(dropped.body["model"] as? String, "m")
        XCTAssertNil(dropped.body["temperature"])
    }

    func testDroppingNothingKeepsTheBody() {
        let unchanged = post(body: ["model": "m", "temperature": 0.0]).dropping([])
        XCTAssertEqual(unchanged.body.count, 2)
    }

    func testDroppingKeepsHeadersAndOptionalKeys() {
        let dropped = post(body: ["model": "m"]).dropping(["temperature"])
        XCTAssertEqual(dropped.headers["x-api-key"], "k")
        XCTAssertEqual(dropped.optionalKeys, ["temperature"])
    }
}
