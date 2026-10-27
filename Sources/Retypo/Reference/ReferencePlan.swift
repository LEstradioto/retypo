import Foundation

/// A file's text, sent whole with the request.
struct ReferenceDocument: Equatable {
    let path: String
    let text: String
}

/// How an enhanced mode's sources reach the model.
enum ReferencePlan: Equatable {
    /// Nothing attached: a web-only enhanced mode.
    case none
    /// Small enough to send whole with every request. Fastest, nothing can
    /// be missed, and any provider can run it. Claude Projects does the
    /// same until its knowledge outgrows the context.
    case inline([ReferenceDocument])
    /// Too much to send whole: the model lists, searches and reads it with
    /// the read-only tools.
    case onDemand(roots: [ReferenceRoot], fileCount: Int)

    var needsTools: Bool {
        if case .onDemand = self { return true }
        return false
    }
}

/// Picks the plan from the size of what is attached.
enum ReferencePlanner {
    /// About 15k tokens: Haiku 5.5 reads that for a fraction of a cent, and
    /// the prompt cache makes repeat runs of the same mode cheaper still.
    static let inlineCharacterBudget = 60_000
    /// More files than this goes on demand without reading any of them.
    static let inlineFileLimit = 40

    /// Reads files, so call it off the main thread.
    /// Example: `ReferencePlanner.plan(for: mode.enhancement?.sources ?? [])`.
    static func plan(for sources: [ReferenceSource]) -> ReferencePlan {
        guard !sources.isEmpty else { return .none }
        let roots = ReferenceCatalog.roots(for: sources)
        let files = ReferenceCatalog.files(in: roots)
        if let documents = inlineDocuments(files) { return .inline(documents) }
        return .onDemand(roots: roots, fileCount: files.count)
    }

    /// nil as soon as the files outgrow the inline budget.
    static func inlineDocuments(_ files: [ReferenceFile]) -> [ReferenceDocument]? {
        guard files.count <= inlineFileLimit else { return nil }
        var documents: [ReferenceDocument] = []
        var characters = 0
        for file in files {
            guard let text = ReferenceTextCache.text(of: file) else { continue }
            characters += text.count
            if characters > inlineCharacterBudget { return nil }
            documents.append(ReferenceDocument(path: file.path, text: text))
        }
        return documents
    }
}
