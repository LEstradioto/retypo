import Foundation
@testable import Retypo

/// A throwaway folder tree of reference files, removed by `remove()`.
final class ReferenceFixture {
    let root: URL
    private let fileManager = FileManager.default

    init() throws {
        root = fileManager.temporaryDirectory
            .appendingPathComponent("retypo-reference-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult
    func write(_ relativePath: String, _ contents: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    func writeData(_ relativePath: String, _ data: Data) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    /// Roots as an enhanced run builds them from attached sources.
    func roots(_ relativePaths: [String]) -> [ReferenceRoot] {
        ReferenceCatalog.roots(for: relativePaths.map { ReferenceSource(url: url($0)) })
    }

    func remove() {
        try? fileManager.removeItem(at: root)
    }
}

/// Replays canned Messages API responses and records every request body.
final class ScriptedProviderSender: ProviderSending {
    private var responses: [[String: Any]]
    private(set) var posts: [ProviderPost] = []

    init(_ responses: [[String: Any]]) {
        self.responses = responses
    }

    func send(_ post: ProviderPost, model: String) async throws -> [String: Any] {
        posts.append(post)
        guard !responses.isEmpty else { throw LLMError.invalidResponse }
        return responses.removeFirst()
    }

    func messages(ofPost index: Int) -> [[String: Any]] {
        posts[index].body["messages"] as? [[String: Any]] ?? []
    }
}

/// Canned Messages API response bodies.
enum AnthropicFixtures {
    static func response(_ content: [[String: Any]], stop: String, usage: [String: Any] = ["input_tokens": 10, "output_tokens": 5]) -> [String: Any] {
        ["content": content, "stop_reason": stop, "usage": usage]
    }

    static func toolUse(id: String, name: String, input: [String: Any]) -> [String: Any] {
        ["type": "tool_use", "id": id, "name": name, "input": input]
    }

    static func text(_ text: String) -> [String: Any] {
        ["type": "text", "text": text]
    }

    static let thinking: [String: Any] = ["type": "thinking", "thinking": "", "signature": "sig-abc"]
}
