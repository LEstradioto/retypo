import Foundation

/// Pulls the request parameter a provider rejected out of its 400 body, so a
/// caller can drop that key and retry instead of failing the whole run.
///
/// OpenAI-shaped errors name it outright:
///   `{"error":{"message":"Unsupported parameter: 'temperature' ...","param":"temperature"}}`
/// Anthropic quotes it inside the message instead:
///   ``{"error":{"message":"`temperature` is deprecated for this model."}}``
///
/// Example: `RejectedParameter.name(in: body) // "reasoning"` for a body whose
/// `param` is `reasoning.effort`.
enum RejectedParameter {
    private static let quoteMarks: [Character] = ["`", "'", "\""]

    static func name(in body: String) -> String? {
        guard let error = errorObject(in: body) else { return nil }
        if let param = error["param"] as? String, !param.isEmpty { return rootKey(param) }
        guard let message = error["message"] as? String else { return nil }
        return quotedToken(in: message).map(rootKey)
    }

    private static func errorObject(in body: String) -> [String: Any]? {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["error"] as? [String: Any]
    }

    /// `reasoning.effort` and `thinking.type.disabled` both identify a nested
    /// field; only the top-level key can be removed from the request body.
    private static func rootKey(_ path: String) -> String {
        String(path.split(separator: ".").first ?? "")
    }

    /// First token wrapped in backticks, single or double quotes. Providers
    /// use all three depending on the endpoint.
    private static func quotedToken(in message: String) -> String? {
        guard let open = message.firstIndex(where: quoteMarks.contains) else { return nil }
        let mark = message[open]
        let rest = message[message.index(after: open)...]
        guard let close = rest.firstIndex(of: mark) else { return nil }
        let token = String(rest[..<close])
        return token.isEmpty ? nil : token
    }
}

/// Remembers, for this app session, which parameters a given provider+model
/// pair rejected, so the 400 round-trip is paid once instead of on every run.
actor RejectedParameterMemory {
    private var rejectedByModel: [String: Set<String>] = [:]

    func rejected(provider: ProviderKind, model: String) -> Set<String> {
        rejectedByModel[Self.key(provider, model)] ?? []
    }

    func remember(_ parameter: String, provider: ProviderKind, model: String) {
        rejectedByModel[Self.key(provider, model), default: []].insert(parameter)
    }

    private static func key(_ provider: ProviderKind, _ model: String) -> String {
        "\(provider.rawValue)|\(model)"
    }
}
