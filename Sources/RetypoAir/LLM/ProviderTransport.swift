import Foundation

/// A JSON POST plus the set of body keys that are safe to drop if the
/// provider rejects them (`temperature`, `reasoning`, …). Required keys such
/// as `model` or `messages` are deliberately not listed: a run must fail
/// loudly rather than silently send a different request.
struct ProviderPost {
    let url: URL
    let headers: [String: String]
    var body: [String: Any]
    let optionalKeys: Set<String>

    func dropping(_ keys: Set<String>) -> ProviderPost {
        guard !keys.isEmpty else { return self }
        var copy = self
        copy.body = body.filter { !keys.contains($0.key) }
        return copy
    }
}

/// Sends provider requests with parameter recovery.
///
/// Providers keep retiring request parameters per model (Anthropic dropped
/// `temperature` on Opus 4.7+, OpenAI rejects it on every reasoning model), so
/// a run that would have died on a 400 instead drops the named parameter,
/// retries once, and remembers the rejection for the rest of the session.
struct ProviderTransport {
    let provider: ProviderKind
    let memory: RejectedParameterMemory

    func send(_ post: ProviderPost, model: String) async throws -> [String: Any] {
        let attempt = post.dropping(await memory.rejected(provider: provider, model: model))
        do {
            return try await perform(attempt)
        } catch LLMError.badStatus(let code, let body) where code == 400 {
            guard let parameter = removableParameter(in: body, from: attempt) else {
                throw LLMError.badStatus(code, body)
            }
            await memory.remember(parameter, provider: provider, model: model)
            DebugLog.log("\(provider.rawValue)/\(model) rejected `\(parameter)`; retrying without it")
            return try await perform(attempt.dropping([parameter]))
        }
    }

    func get(url: URL, headers: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return try await decode(request)
    }

    private func perform(_ post: ProviderPost) async throws -> [String: Any] {
        var request = URLRequest(url: post.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in post.headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = try JSONSerialization.data(withJSONObject: post.body)
        return try await decode(request)
    }

    private func decode(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTPStatus.validate(response, data: data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        return object
    }

    private func removableParameter(in body: String, from post: ProviderPost) -> String? {
        guard let name = RejectedParameter.name(in: body),
              post.optionalKeys.contains(name),
              post.body[name] != nil else { return nil }
        return name
    }
}
