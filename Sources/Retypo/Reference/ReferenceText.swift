import AppKit
import PDFKit

/// Plain text the model can read from an attached file, or nil when the
/// file holds nothing readable (images, archives, binaries).
///
/// "Documents" in practice means PDFs and Word files as much as Markdown,
/// so PDFKit and the AppKit document readers cover those; everything else
/// is read as text and rejected if it looks binary.
enum ReferenceText {
    /// Skipped without opening: never text, and some are large.
    static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "ico", "icns", "svgz",
        "mp3", "mp4", "mov", "m4a", "wav", "aiff", "zip", "gz", "tgz", "bz2", "xz", "7z", "rar",
        "dmg", "pkg", "app", "exe", "dylib", "so", "a", "o", "class", "jar", "wasm",
        "sqlite", "db", "psd", "sketch", "fig", "ttf", "otf", "woff", "woff2", "pages", "numbers", "key"
    ]
    /// Read through `NSAttributedString`. HTML stays plain text: its importer
    /// runs WebKit, which must not run off the main thread.
    static let richExtensions: Set<String> = ["rtf", "rtfd", "doc", "docx", "odt"]
    /// Larger plain files are logs or dumps, not reference material.
    static let maxPlainBytes = 4_000_000

    static func isCandidate(_ url: URL) -> Bool {
        !binaryExtensions.contains(url.pathExtension.lowercased())
    }

    /// Example: `ReferenceText.extract(from: URL(fileURLWithPath: "/Users/me/faq.pdf"))`.
    static func extract(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" { return nonEmpty(PDFDocument(url: url)?.string) }
        if richExtensions.contains(ext) { return nonEmpty(richText(url)) }
        guard isCandidate(url) else { return nil }
        return nonEmpty(plainText(url))
    }

    private static func richText(_ url: URL) -> String? {
        try? NSAttributedString(url: url, options: [:], documentAttributes: nil).string
    }

    /// A NUL byte in the first 8 KB marks a binary file; text in a legacy
    /// encoding (Latin-1 notes are common) falls back instead of failing.
    private static func plainText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count <= maxPlainBytes,
              !data.prefix(8_192).contains(0) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}
