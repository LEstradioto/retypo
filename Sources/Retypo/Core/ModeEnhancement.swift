import Foundation

/// What turns a plain mode (one request, one answer) into an enhanced one:
/// files and folders the model may consult, and live web search. A mode
/// with `enhancement == nil` stays plain.
///
/// The shape follows what Custom GPTs, Claude Projects and Raycast presets
/// settled on: instructions, plus knowledge, plus capability toggles.
struct ModeEnhancement: Codable, Hashable {
    /// Switching Enhanced off keeps the attached sources, so switching it
    /// back on does not mean picking every file again.
    var isOn = true
    var sources: [ReferenceSource] = []
    var webSearch = false

    init(isOn: Bool = true, sources: [ReferenceSource] = [], webSearch: Bool = false) {
        self.isOn = isOn
        self.sources = sources
        self.webSearch = webSearch
    }

    /// On, but with nothing attached and the web off, a mode has nothing
    /// to research, so it runs as a plain one.
    var isActive: Bool { isOn && (!sources.isEmpty || webSearch) }

    private enum CodingKeys: String, CodingKey {
        case isOn, sources, webSearch
    }

    /// Field by field, so a later field never breaks `modes.json` files
    /// written by this version.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
        sources = try container.decodeIfPresent([ReferenceSource].self, forKey: .sources) ?? []
        webSearch = try container.decodeIfPresent(Bool.self, forKey: .webSearch) ?? false
    }

    /// Adds sources that are not attached yet, keeping the order they came in.
    mutating func attach(_ newSources: [ReferenceSource]) {
        for source in newSources where !sources.contains(source) {
            sources.append(source)
        }
    }
}

/// A file or folder attached to an enhanced mode, stored as an absolute
/// path. Retypo is not sandboxed, so no security-scoped bookmark is needed.
struct ReferenceSource: Codable, Hashable, Identifiable {
    var path: String
    var isFolder: Bool

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path, isDirectory: isFolder) }
    var name: String { url.lastPathComponent }

    /// Example: `ReferenceSource(url: URL(fileURLWithPath: "/Users/me/docs"))`.
    init(url: URL) {
        let standardized = url.standardizedFileURL
        path = standardized.path
        isFolder = (try? standardized.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    init(path: String, isFolder: Bool) {
        self.path = path
        self.isFolder = isFolder
    }
}

extension EditAction {
    /// Enhanced and with something to research: runs through the research
    /// path instead of a single request.
    var isEnhanced: Bool { enhancement?.isActive == true }

    /// Correct answers through its own JSON contract (`correctionSystem`),
    /// not the edit prompt the research loop builds on.
    var canBeEnhanced: Bool { id != "correct" }
}
