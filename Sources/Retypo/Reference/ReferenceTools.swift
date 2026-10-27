import Foundation

/// The three read-only tools over the attached sources. Descriptions say
/// when to call each one, which small models need to search reliably.
enum ReferenceTools {
    static let list = ToolSpec(
        name: "list_files",
        description: "List the attached reference files, optionally only under one folder or only names matching a pattern. Call it first when you do not know what material exists.",
        parameters: schema([
            "path": property("string", "Folder or file to list, as shown in earlier results, e.g. \"docs/faq\". Omit to list everything."),
            "pattern": property("string", "File-name glob, e.g. \"*.md\" or \"*refund*\".")
        ], required: [])
    )

    static let search = ToolSpec(
        name: "search_files",
        description: "Find lines in the attached files that contain a word or phrase, ignoring case and accents. Call it whenever the text mentions a product, policy, name, number or fact the sources may define. Separate alternatives with |, e.g. \"refund|reembolso\". Returns path:line: text.",
        parameters: schema([
            "query": property("string", "Word or phrase to find; alternatives separated by |."),
            "path": property("string", "Only search under this folder or file. Omit to search everything.")
        ], required: ["query"])
    )

    static let read = ToolSpec(
        name: "read_file",
        description: "Read an attached file with line numbers, up to 400 lines per call. Read around search hits before relying on them. Use start_line to continue a long file.",
        parameters: schema([
            "path": property("string", "File path as shown by list_files or search_files."),
            "start_line": property("integer", "First line to read, 1-based. Defaults to 1."),
            "end_line": property("integer", "Last line to read. Defaults to 400 lines after start_line.")
        ], required: ["path"])
    )

    static let all = [list, search, read]

    private static func schema(_ properties: [String: Any], required: [String]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": required]
    }

    private static func property(_ type: String, _ description: String) -> [String: Any] {
        ["type": type, "description": description]
    }
}

enum ReferenceToolError: LocalizedError, Equatable {
    case outsideSources(String)
    case notFound(String)
    case unreadable(String)
    case isFolder(String)
    case missingArgument(tool: String, field: String)
    case unknownTool(String)
    case budgetExhausted(Int)

    var errorDescription: String? {
        switch self {
        case .outsideSources(let path): "\"\(path)\" is outside the attached sources. Use a path as shown by list_files, such as \"docs/notes.md\"."
        case .notFound(let path): "\"\(path)\" does not exist in the attached sources. Call list_files to see the available paths."
        case .unreadable(let path): "\"\(path)\" has no readable text (binary or empty)."
        case .isFolder(let path): "\"\(path)\" is a folder. Call list_files with this path to see its files."
        case .missingArgument(let tool, let field): "\(tool) needs a non-empty \"\(field)\" string argument."
        case .unknownTool(let name): "Unknown tool \"\(name)\". Available: list_files, search_files, read_file."
        case .budgetExhausted(let limit): "The reading budget for this run (\(limit) characters) is used up. Answer with what you have."
        }
    }
}
