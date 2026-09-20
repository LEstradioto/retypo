import AppKit
import SwiftUI

/// Hex inelegance for the editor font-color override (`settings.fontColorHex`).
/// `nil`/unparseable means "follow the system label color".
enum FontColorHex {
    static func color(from hex: String?) -> NSColor? {
        guard let hex else { return nil }
        let digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// `ColorPicker` gives back a SwiftUI `Color`; the `NSColor(Color)`
    /// bridge is macOS 14+, so on 13 the save is skipped and the old
    /// value stays.
    static func hex(from color: Color) -> String? {
        if #available(macOS 14, *) {
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
            return String(format: "#%02X%02X%02X",
                          Int(rgb.redComponent * 255),
                          Int(rgb.greenComponent * 255),
                          Int(rgb.blueComponent * 255))
        }
        return nil
    }
}
