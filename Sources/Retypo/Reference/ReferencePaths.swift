import Foundation

/// A model-supplied path mapped onto disk, inside one attached root.
struct ResolvedReference: Equatable {
    let root: ReferenceRoot
    let url: URL
}

/// The one place model-supplied paths become disk locations.
///
/// The model may send a labelled path (`docs/faq.md`), `./docs/faq.md`, or
/// an absolute path it saw somewhere. Each is standardized (`..` removed),
/// its symlinks resolved, then checked against the attached roots: a folder
/// root contains everything below it, a file root only itself.
enum ReferencePaths {
    static func resolve(_ raw: String, in roots: [ReferenceRoot]) throws -> ResolvedReference {
        let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = path.hasPrefix("/") ? canonical(URL(fileURLWithPath: path)) : labelled(path, roots)
        guard let candidate, let root = containingRoot(of: candidate, in: roots) else {
            throw ReferenceToolError.outsideSources(raw)
        }
        guard !isHidden(candidate, below: root) else { throw ReferenceToolError.notShared(raw) }
        return ResolvedReference(root: root, url: candidate)
    }

    /// What `list_files` leaves out stays out of reach too: dotfiles such as
    /// `.env` inside an attached project, and dependency folders. A hidden
    /// file the user attached by name is the root itself, so it stays readable.
    static func isHidden(_ url: URL, below root: ReferenceRoot) -> Bool {
        guard root.isFolder, url.path.count > root.url.path.count else { return false }
        let relative = url.path.dropFirst(root.url.path.count + 1).split(separator: "/")
        return relative.contains { $0.hasPrefix(".") || ReferenceCatalog.skippedFolders.contains(String($0)) }
    }

    /// The most specific match: a file attached by name wins over the
    /// attached folder it sits in, so its own (unhidden) rules apply.
    static func containingRoot(of url: URL, in roots: [ReferenceRoot]) -> ReferenceRoot? {
        roots.filter { root in
            url.path == root.url.path || (root.isFolder && url.path.hasPrefix(root.url.path + "/"))
        }.max { $0.url.path.count < $1.url.path.count }
    }

    private static func labelled(_ path: String, _ roots: [ReferenceRoot]) -> URL? {
        let trimmed = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        let parts = trimmed.split(separator: "/", maxSplits: 1).map(String.init)
        guard let label = parts.first, let root = root(labelled: label, in: roots) else { return nil }
        guard parts.count > 1 else { return root.url }
        return canonical(root.url.appendingPathComponent(parts[1]))
    }

    /// Exact label first; models sometimes change the case of a name.
    private static func root(labelled label: String, in roots: [ReferenceRoot]) -> ReferenceRoot? {
        roots.first { $0.label == label } ?? roots.first { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
