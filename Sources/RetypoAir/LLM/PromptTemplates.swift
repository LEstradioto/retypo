import Foundation

enum PromptTemplates {
    private static let correctionPrelude = """
Edit the user's text according to the instruction below.
Preserve file paths, commands, flags, identifiers, markdown, and code blocks unless the instruction explicitly asks otherwise.
"""

    private static let correctionContract = """
Return JSON only with this exact schema:
{"corrected":"...", "changed":true, "confidence":0.0}
"""

    static func correctionSystem(instruction: String) -> String {
        """
\(correctionPrelude)
Instruction:
\(instruction)
\(correctionContract)
"""
    }

    static func correctionUser(_ text: String) -> String {
        """
Text to edit:

\(text)
"""
    }

    static func actionSystem(instruction: String) -> String {
        """
You edit text exactly as requested.
Preserve technical identifiers, file paths, commands, flags, code blocks, and markdown unless the instruction explicitly asks otherwise.
Return only the edited text, no commentary.

Instruction:
\(instruction)
"""
    }
}
