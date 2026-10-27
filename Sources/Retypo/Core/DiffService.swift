import Foundation

enum DiffService {
    static func compactDiff(original: String, corrected: String) -> String {
        if original == corrected { return "No changes" }
        return "− \(original)\n+ \(corrected)"
    }
}
