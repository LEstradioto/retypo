import Foundation

/// Target language for live translation. Curated list — the card switcher
/// and the settings key both use `code` (BCP-47).
struct TargetLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let supported: [TargetLanguage] = [
        TargetLanguage(code: "pt-BR", name: "Portuguese (BR)"),
        TargetLanguage(code: "en", name: "English"),
        TargetLanguage(code: "es", name: "Spanish"),
        TargetLanguage(code: "fr", name: "French"),
        TargetLanguage(code: "de", name: "German"),
        TargetLanguage(code: "it", name: "Italian"),
        TargetLanguage(code: "ja", name: "Japanese"),
        TargetLanguage(code: "ko", name: "Korean"),
        TargetLanguage(code: "zh-Hans", name: "Chinese (Simplified)"),
        TargetLanguage(code: "ru", name: "Russian")
    ]

    /// Unknown codes fall back to the first supported language.
    static func named(_ code: String) -> TargetLanguage {
        supported.first { $0.code == code } ?? supported[0]
    }

    /// Base-language comparison for translation purposes: pt and pt-BR are
    /// the same language, so translating between them is a no-op.
    func isSameBaseLanguage(as otherCode: String) -> Bool {
        Self.baseCode(code) == Self.baseCode(otherCode)
    }

    private static func baseCode(_ code: String) -> String {
        let base = code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first
        return (base.map(String.init) ?? code).lowercased()
    }
}
