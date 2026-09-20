import AppKit
import SwiftUI

/// Explicit palette for the curated preset themes. `nil` definition means
/// "follow the system NSColors" (Light / Dark / System) — see `Palette`.
struct ThemeDefinition {
    var window: Color
    var editor: Color
    var card: Color
    var hairline: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var accent: Color

    init(window: String, editor: String, card: String, hairline: String,
         primaryText: String, secondaryText: String, tertiaryText: String, accent: String) {
        self.window = Color(hex: window)
        self.editor = Color(hex: editor)
        self.card = Color(hex: card)
        self.hairline = Color(hex: hairline)
        self.primaryText = Color(hex: primaryText)
        self.secondaryText = Color(hex: secondaryText)
        self.tertiaryText = Color(hex: tertiaryText)
        self.accent = Color(hex: accent)
    }

    static let monokai = ThemeDefinition(
        window: "272822", editor: "1E1F1C", card: "3E3D32", hairline: "49483E",
        primaryText: "F8F8F2", secondaryText: "B8B8B0", tertiaryText: "75715E",
        accent: "A6E22E"
    )

    static let tokyoNight = ThemeDefinition(
        window: "1A1B26", editor: "16161E", card: "24283B", hairline: "2F3549",
        primaryText: "C0CAF5", secondaryText: "9AA5CE", tertiaryText: "565F89",
        accent: "7AA2F7"
    )

    static let catppuccin = ThemeDefinition(
        window: "1E1E2E", editor: "11111B", card: "313244", hairline: "45475A",
        primaryText: "CDD6F4", secondaryText: "A6ADC8", tertiaryText: "6C7086",
        accent: "CBA6F7"
    )
}

extension Color {
    /// Solid compile-time hex (`"1A1B26"` or `"#1A1B26"`). Traps on a
    /// malformed literal, same contract as `URL(staticString:)`.
    init(hex: String) {
        let digits = hex.replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            preconditionFailure("invalid static hex color: \(hex)")
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
