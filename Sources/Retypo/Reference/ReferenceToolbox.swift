import Foundation

/// The read-only tools an enhanced run gives the model over its attached
/// sources: list, search, read. Nothing here writes, runs commands, or
/// touches the network, and every path goes through `ReferencePaths`, so a
/// model cannot reach files the user did not attach.
///
/// One instance lives for one run; it caches the file list and caps the
/// total text it hands out.
final class ReferenceToolbox {
    static let listLimit = 200
    static let searchLimit = 40
    static let readLineLimit = 400
    static let readCharacterLimit = 30_000
    /// So a confused model cannot pull a whole vault into one conversation.
    static let runCharacterBudget = 300_000

    let roots: [ReferenceRoot]
    private(set) lazy var files: [ReferenceFile] = ReferenceCatalog.files(in: roots)
    private var charactersReturned = 0

    init(roots: [ReferenceRoot]) {
        self.roots = roots
    }

    /// Never throws: failures go back to the model as error results it can
    /// act on (a wrong path, a missing argument).
    func run(_ call: ToolCall) -> ToolOutcome {
        do {
            let content = try charge(try dispatch(call))
            return ToolOutcome(callID: call.id, content: content, isError: false)
        } catch {
            return ToolOutcome(callID: call.id, content: error.localizedDescription, isError: true)
        }
    }

    private func dispatch(_ call: ToolCall) throws -> String {
        switch call.name {
        case ReferenceTools.list.name:
            return try list(under: call.string("path"), pattern: call.string("pattern"))
        case ReferenceTools.search.name:
            return try search(try required("query", of: call), under: call.string("path"))
        case ReferenceTools.read.name:
            return try read(try required("path", of: call), from: call.integer("start_line"), to: call.integer("end_line"))
        default:
            throw ReferenceToolError.unknownTool(call.name)
        }
    }

    private func required(_ field: String, of call: ToolCall) throws -> String {
        guard let value = call.string(field) else { throw ReferenceToolError.missingArgument(tool: call.name, field: field) }
        return value
    }

    /// Checked before handing the text out, so one read cannot cross it.
    private func charge(_ content: String) throws -> String {
        guard charactersReturned + content.count <= Self.runCharacterBudget else {
            throw ReferenceToolError.budgetExhausted(Self.runCharacterBudget)
        }
        charactersReturned += content.count
        return content
    }

    func list(under path: String?, pattern: String?) throws -> String {
        let scope = try path.map { try ReferencePaths.resolve($0, in: roots) }
        let matching = files.filter { isInside($0, scope) && ReferenceListing.matches($0, pattern: pattern) }
        return ReferenceListing.render(matching, limit: Self.listLimit)
    }

    func search(_ query: String, under path: String?) throws -> String {
        let scope = try path.map { try ReferencePaths.resolve($0, in: roots) }
        let needles = ReferenceSearch.needles(from: query)
        guard !needles.isEmpty else { throw ReferenceToolError.missingArgument(tool: ReferenceTools.search.name, field: "query") }
        var hits = ReferenceSearch.Hits(limit: Self.searchLimit)
        for file in files where isInside(file, scope) {
            guard let text = ReferenceTextCache.text(of: file) else { continue }
            hits.collect(from: text, path: file.path, needles: needles)
        }
        return hits.render(query: query)
    }

    func read(_ path: String, from start: Int?, to end: Int?) throws -> String {
        let resolved = try ReferencePaths.resolve(path, in: roots)
        let file = try readableFile(at: resolved, requested: path)
        guard let text = ReferenceTextCache.text(of: file) else { throw ReferenceToolError.unreadable(path) }
        let window = ReferenceExcerpt.Window(start: start, end: end, lineLimit: Self.readLineLimit)
        return ReferenceExcerpt.render(text, path: file.path, window: window, characterLimit: Self.readCharacterLimit)
    }

    private func readableFile(at resolved: ResolvedReference, requested: String) throws -> ReferenceFile {
        let values = try? resolved.url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
        if values?.isDirectory == true { throw ReferenceToolError.isFolder(requested) }
        guard values?.isRegularFile == true else { throw ReferenceToolError.notFound(requested) }
        let path = resolved.root.isFolder ? ReferenceCatalog.displayPath(of: resolved.url, in: resolved.root) : resolved.root.label
        return ReferenceFile(path: path, url: resolved.url, byteSize: values?.fileSize ?? 0)
    }

    private func isInside(_ file: ReferenceFile, _ scope: ResolvedReference?) -> Bool {
        guard let scope else { return true }
        return file.url.path == scope.url.path || file.url.path.hasPrefix(scope.url.path + "/")
    }
}
