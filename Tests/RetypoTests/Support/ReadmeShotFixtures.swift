import Foundation
@testable import Retypo

/// Sample content for the README screenshots (see `ReadmeShotsTests`).
enum ReadmeShotFixtures {
    /// Speed-typed, the way the panel is meant to be used.
    static let draft = """
    So now we can spee dtyuptig without even think if we are being write enough. \
    If we type really long lien with some context the llm is smart enough to doa lot \
    of the heavy lifting and make this pharese way wayyy better than I could.

    Is that so? ... damn I fel so unstopapblkeaa right now eheeey????
    """

    /// What "Improve Writing" made of `draft`.
    static let revised = """
    Now we can speed-type without even thinking about whether we're writing correctly. \
    If we type really long lines with some context, the LLM is smart enough to do a lot \
    of the heavy lifting and make these phrases way better than I could.

    Is that so? Damn, I feel unstoppable right now!
    """

    /// A short message for the run-all cards, so three of them fit.
    static let request = "hey can u send me the report by tmrw? i need it for the meeting w/ the board, thx"

    static let candidates: [(modeID: String, output: String)] = [
        ("correct", "Hey, can you send me the report by tomorrow? I need it for the meeting with the board. Thanks!"),
        ("improve", "Could you send me the report by tomorrow? I need it for the board meeting. Thank you!"),
        ("simplify", "Please send the report by tomorrow for the board meeting. Thanks!")
    ]

    static let docsModeID = "answer-from-docs"

    /// An enhanced mode that answers from a docs folder, a price list and the
    /// web. The files are real, so the editor can measure them.
    static func docsMode(in folder: URL) throws -> EditAction {
        let docs = folder.appendingPathComponent("support-docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        for (name, text) in docsFiles {
            try text.write(to: docs.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let prices = folder.appendingPathComponent("pricing-2026.md")
        try "# Pricing 2026\n\nStarter: $9/month. Team: $29/month per 5 seats. Annual billing saves 20%.\n".write(to: prices, atomically: true, encoding: .utf8)
        return EditAction(
            id: docsModeID, title: "Answer from docs",
            instruction: "Answer the customer using only our support docs and the 2026 price list, and name the doc you used. If the docs do not cover it, check the web and say so. Keep it short, friendly, and in the customer's language.",
            enhancement: ModeEnhancement(sources: [ReferenceSource(url: docs), ReferenceSource(url: prices)], webSearch: true)
        )
    }

    private static let docsFiles: [(String, String)] = [
        ("refunds.md", "# Refunds\n\nFull refund within 30 days of purchase, no questions asked. After that, prorated credit.\n"),
        ("plans.md", "# Plans\n\nStarter covers one person. Team adds shared modes and an admin console.\n"),
        ("onboarding.md", "# Onboarding\n\nInvite teammates from Settings. Each invite expires after 7 days.\n")
    ]
}
