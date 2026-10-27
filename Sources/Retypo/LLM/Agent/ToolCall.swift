import Foundation

/// A tool definition in a provider-neutral shape; each adapter renders it
/// in its own wire format.
struct ToolSpec {
    let name: String
    let description: String
    /// JSON Schema of the arguments object.
    let parameters: [String: Any]
}

/// A tool call the model asked for.
struct ToolCall {
    let id: String
    let name: String
    let arguments: [String: Any]

    /// Blank strings count as missing.
    func string(_ key: String) -> String? {
        guard let value = arguments[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Models send line numbers as JSON integers, floats or strings.
    func integer(_ key: String) -> Int? {
        switch arguments[key] {
        case let value as Int: return value
        case let value as Double: return Int(value)
        case let value as String: return Int(value)
        default: return nil
        }
    }
}

/// What a tool returns to the model. Errors go back as results too, so the
/// model can correct a bad path instead of the run failing.
struct ToolOutcome: Equatable {
    let callID: String
    let content: String
    let isError: Bool
}
