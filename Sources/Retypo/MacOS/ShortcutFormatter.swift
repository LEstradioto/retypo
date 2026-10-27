import AppKit

enum ShortcutFormatter {
    static func string(from event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
        guard let key = keyName(from: event), !key.isEmpty else { return nil }
        var parts: [String] = []
        if flags.contains(.command) { parts.append("cmd") }
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.option) { parts.append("opt") }
        if flags.contains(.shift) { parts.append("shift") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    static func normalize(_ shortcut: String) -> String {
        var text = shortcut
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "command", with: "cmd")
            .replacingOccurrences(of: "option", with: "opt")
            .replacingOccurrences(of: "control", with: "ctrl")
            .replacingOccurrences(of: "⌘", with: "cmd+")
            .replacingOccurrences(of: "⌥", with: "opt+")
            .replacingOccurrences(of: "⌃", with: "ctrl+")
            .replacingOccurrences(of: "⇧", with: "shift+")
            .replacingOccurrences(of: " ", with: "")
        while text.contains("++") { text = text.replacingOccurrences(of: "++", with: "+") }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "+"))
        guard !text.isEmpty else { return "" }

        let parts = text.split(separator: "+").map(String.init)
        let mods = ["cmd", "ctrl", "opt", "shift"].filter { parts.contains($0) }
        let key = parts.last { !["cmd", "ctrl", "opt", "shift"].contains($0) } ?? ""
        return (mods + [key]).filter { !$0.isEmpty }.joined(separator: "+")
    }

    private static let keyNamesByCode: [Int: String] = [
        36: "enter", 76: "enter",
        49: "space", 53: "esc",
        115: "home", 119: "end",
        123: "left", 124: "right", 125: "down", 126: "up"
    ]

    private static func keyName(from event: NSEvent) -> String? {
        if let name = keyNamesByCode[Int(event.keyCode)] { return name }
        return event.charactersIgnoringModifiers?.lowercased()
    }
}
