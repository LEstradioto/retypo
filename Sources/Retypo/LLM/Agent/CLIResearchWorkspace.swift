import Foundation

/// The folder a CLI research run starts in. Attached single files are
/// copied in under their labels, so Claude Code reads them as working-
/// directory files instead of being granted the whole folder they sit in.
/// Attached folders are granted as they are, with `--add-dir`.
struct CLIResearchWorkspace {
    let url: URL?
    let access: CLIResearchAccess
    /// Where the CLI's own tools find each source, by label.
    let paths: [String: String]

    /// Example: `try CLIResearchWorkspace(plan: plan, webSearch: true)`, then
    /// `workspace.remove()` once the run is over.
    init(plan: ReferencePlan, webSearch: Bool) throws {
        let roots: [ReferenceRoot]
        if case .onDemand(let attached, _) = plan { roots = attached } else { roots = [] }
        let files = roots.filter { !$0.isFolder }
        let url = files.isEmpty ? nil : try Self.copy(files)
        var paths: [String: String] = [:]
        for root in roots {
            paths[root.label] = root.isFolder ? root.url.path : url?.appendingPathComponent(root.label).path
        }
        self.url = url
        self.paths = paths
        access = CLIResearchAccess(folders: roots.filter(\.isFolder).map(\.url.path), workspace: url, webSearch: webSearch)
    }

    func remove() {
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    private static func copy(_ files: [ReferenceRoot]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("retypo-research-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for file in files {
            try FileManager.default.copyItem(at: file.url, to: url.appendingPathComponent(file.label))
        }
        return url
    }
}
