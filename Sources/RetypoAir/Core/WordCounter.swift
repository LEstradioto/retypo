import Foundation

protocol WordCounting {
    func countWords(in text: String) -> Int
}

struct LocalizedWordCounter: WordCounting {
    func countWords(in text: String) -> Int {
        let text = text as NSString
        var wordCount = 0
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: text.length),
            options: [.byWords, .localized]
        ) { _, _, _, _ in
            wordCount += 1
        }
        return wordCount
    }
}
