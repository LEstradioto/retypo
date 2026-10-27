import Foundation

/// Turns a provider's raw JSON error body into one readable sentence.
///
/// The panel status bar is a single truncated line, so the previous
/// `body.prefix(280)` of raw JSON showed `{"type":"error","error":{"type":...`
/// and cut off before the part that says what went wrong. Every provider we
/// talk to nests the human text under `error.message`.
///
/// Example: `ProviderErrorMessage.summary(body) // "`temperature` is deprecated for this model."`
enum ProviderErrorMessage {
    static func summary(_ body: String, limit: Int = 400) -> String {
        let text = message(in: body) ?? body.trimmingCharacters(in: .whitespacesAndNewlines)
        let flattened = text.replacingOccurrences(of: "\n", with: " ")
        guard flattened.count > limit else { return flattened }
        return flattened.prefix(limit) + "…"
    }

    private static func message(in body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = object["error"] as? [String: Any] { return error["message"] as? String }
        // OpenRouter surfaces upstream failures as a bare `message` field.
        return object["message"] as? String
    }
}

enum HTTPStatus {
    /// Validates a provider response, raising `LLMError.badStatus` with the
    /// body attached so the caller can both show it and inspect it for a
    /// rejected parameter.
    static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
