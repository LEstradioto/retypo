import Foundation

struct EditAction: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var instruction: String
    var isEnabled: Bool = true

    /// The id of the always-present "freeform" mode, where the user types the
    /// instruction in real time instead of saving it ahead of time. Cannot be
    /// deleted or its id reused.
    static let freeformID = "freeform"

    static let defaults: [EditAction] = [
        EditAction(id: "correct", title: "Correct", instruction: "Fix typos only. Preserve wording, tone, punctuation style, and language unless a typo requires a minimal correction."),
        EditAction(id: "typos-grammar", title: "Typos and Grammar", instruction: "Fix typos, grammar, punctuation, and awkward grammatical mistakes while preserving the original meaning, voice, and language."),
        EditAction(id: "improve", title: "Improve Writing", instruction: "Rewrite the text to improve clarity, flow, and grammar while preserving meaning and tone."),
        EditAction(id: "translate", title: "Translate", instruction: "Translate the text to English if it is not English; translate it to natural Brazilian Portuguese if it is already English."),
        EditAction(id: "simplify", title: "Simplify", instruction: "Simplify the text. Keep meaning. Use concise natural wording."),
        EditAction(id: "summarize", title: "Summarize", instruction: "Summarize the text in a compact paragraph."),
        EditAction(id: "bullets", title: "Bullets", instruction: "Convert the text into clear bullet points."),
        EditAction(id: "better-way", title: "Better way of saying", instruction: "Rewrite the text as a better, more natural way of saying the same thing. Keep it concise and preserve intent."),
        EditAction(id: "tweet-fit", title: "Make this Tweet Fit", instruction: "Rewrite the text to fit within 280 characters for X/Twitter. Preserve the core point and make it natural."),
        EditAction(id: "variations-3", title: "Generate 3 variations", instruction: "Generate three distinct polished variations of the text. Number them 1, 2, and 3."),
        EditAction(id: "respond-3-ways", title: "How to respond 3 ways", instruction: "Suggest three possible replies to the text: one concise, one friendly, and one direct. Number them 1, 2, and 3."),
        EditAction(id: "caveman", title: "Caveman", instruction: "Rewrite the text in an intentionally simple caveman style. Keep the meaning, use short blunt words, and avoid complex grammar."),
        EditAction(id: freeformID, title: "Freeform", instruction: "")
    ]

    var hasCustomizedDefault: Bool {
        guard let defaultAction = Self.defaults.first(where: { $0.id == id }) else { return false }
        return title != defaultAction.title || instruction != defaultAction.instruction
    }

    mutating func resetToDefault() -> Bool {
        guard let defaultAction = Self.defaults.first(where: { $0.id == id }) else { return false }
        title = defaultAction.title
        instruction = defaultAction.instruction
        return true
    }
}

enum EditActionStore {
    private static let file = PersistedFile<[EditAction]>(
        url: AppFiles.url("modes.json"),
        fallback: EditAction.defaults
    )

    static func load() -> [EditAction] {
        let stored = file.load()
        if stored.isEmpty {
            save(EditAction.defaults)
            return EditAction.defaults
        }
        let merged = mergeDefaults(into: stored)
        if merged != stored { save(merged) }
        return merged
    }

    static func save(_ actions: [EditAction]) { file.save(actions) }

    private static func mergeDefaults(into actions: [EditAction]) -> [EditAction] {
        guard !actions.isEmpty else { return EditAction.defaults }
        var result = actions
        let existingIDs = Set(actions.map(\.id))
        for action in EditAction.defaults where !existingIDs.contains(action.id) {
            result.append(action)
        }
        return result
    }
}
