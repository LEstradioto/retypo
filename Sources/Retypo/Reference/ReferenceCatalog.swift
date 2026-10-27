import Foundation

/// One attached source as the model sees it: a short label (`docs`,
/// `glossary.md`) standing for a real location on disk.
struct ReferenceRoot: Equatable {
    let label: String
    /// Symlinks resolved, so containment checks compare real paths.
    let url: URL
    let isFolder: Bool
}

/// A file under one of the roots that may hold readable text.
struct ReferenceFile: Equatable {
    /// What the model sees and sends back, e.g. `docs/faq/billing.md`.
    let path: String
    let url: URL
    let byteSize: Int
}

/// Turns attached sources into roots and the files under them.
enum ReferenceCatalog {
    /// Build output and dependencies, never knowledge.
    static let skippedFolders: Set<String> = ["node_modules", "build", "dist", "DerivedData", "Pods", "target", "__pycache__"]
    /// Enough for a docs folder or a notes vault; keeps an attached home
    /// folder from turning one run into a full-disk crawl.
    static let fileLimit = 5_000

    /// Two folders both named `docs` become `docs` and `docs-2`.
    static func roots(for sources: [ReferenceSource]) -> [ReferenceRoot] {
        var used: Set<String> = []
        return sources.map { source in
            let label = uniqueLabel(source.name, used: &used)
            return ReferenceRoot(label: label, url: source.url.resolvingSymlinksInPath(), isFolder: source.isFolder)
        }
    }

    /// Roots in the order attached, paths sorted within each folder.
    static func files(in roots: [ReferenceRoot], limit: Int = fileLimit) -> [ReferenceFile] {
        var files: [ReferenceFile] = []
        for root in roots where files.count < limit {
            files += root.isFolder ? folderFiles(root, limit: limit - files.count) : singleFile(root)
        }
        return files
    }

    private static func uniqueLabel(_ name: String, used: inout Set<String>) -> String {
        let base = name.isEmpty ? "source" : name
        var label = base
        var suffix = 2
        while used.contains(label) {
            label = "\(base)-\(suffix)"
            suffix += 1
        }
        used.insert(label)
        return label
    }

    private static func singleFile(_ root: ReferenceRoot) -> [ReferenceFile] {
        let values = try? root.url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true else { return [] }
        return [ReferenceFile(path: root.label, url: root.url, byteSize: values?.fileSize ?? 0)]
    }

    private static func folderFiles(_ root: ReferenceRoot, limit: Int) -> [ReferenceFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let walker = FileManager.default.enumerator(at: root.url, includingPropertiesForKeys: keys, options: options) else { return [] }
        var files: [ReferenceFile] = []
        while files.count < limit, let url = walker.nextObject() as? URL {
            if let file = entry(url, root: root, walker: walker) { files.append(file) }
        }
        return files.sorted { $0.path < $1.path }
    }

    /// Symlinked files report as neither regular file nor folder and are
    /// left out; the tools refuse paths that resolve outside the roots.
    private static func entry(_ url: URL, root: ReferenceRoot, walker: FileManager.DirectoryEnumerator) -> ReferenceFile? {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
        if values?.isDirectory == true {
            if skippedFolders.contains(url.lastPathComponent) { walker.skipDescendants() }
            return nil
        }
        guard values?.isRegularFile == true, ReferenceText.isCandidate(url) else { return nil }
        return ReferenceFile(path: displayPath(of: url, in: root), url: url, byteSize: values?.fileSize ?? 0)
    }

    /// `docs` + `/…/docs/faq/billing.md` → `docs/faq/billing.md`.
    static func displayPath(of url: URL, in root: ReferenceRoot) -> String {
        let base = root.url.path
        let full = url.path.hasPrefix(base + "/") ? url.path : url.resolvingSymlinksInPath().path
        guard full.hasPrefix(base + "/") else { return root.label }
        return "\(root.label)/\(full.dropFirst(base.count + 1))"
    }
}

/// Extracted text, kept between runs while the file is unchanged. PDFs and
/// Word files are slow to parse, and a vault searched twice should not be
/// parsed twice. `NSCache` is thread-safe and drops entries under pressure.
enum ReferenceTextCache {
    private static let cache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.totalCostLimit = 64 * 1_024 * 1_024
        return cache
    }()

    static func text(of file: ReferenceFile) -> String? {
        let key = cacheKey(file) as NSString
        if let hit = cache.object(forKey: key) { return hit as String }
        guard let text = ReferenceText.extract(from: file.url) else { return nil }
        cache.setObject(text as NSString, forKey: key, cost: text.utf8.count)
        return text
    }

    private static func cacheKey(_ file: ReferenceFile) -> String {
        let modified = try? file.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return "\(file.url.path)|\(file.byteSize)|\(modified?.timeIntervalSince1970 ?? 0)"
    }
}
