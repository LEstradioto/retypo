import Foundation

struct PromptStatusLineClassifier {
    func isStatusLine(_ line: String) -> Bool {
        let lower = line.trimmingCharacters(in: .whitespaces).lowercased()
        return statusLineFragments.contains { lower.contains($0) } ||
            isModelStatusLine(lower) || isWorkspaceStatusLine(lower) || isBuildStatusLine(lower)
    }

    private func isModelStatusLine(_ line: String) -> Bool {
        line.contains("context ") && line.contains(" window") ||
            line.contains("goal achieved") ||
            line.contains("gpt-") && line.contains("used")
    }

    private func isWorkspaceStatusLine(_ line: String) -> Bool {
        line.hasPrefix("workspace-") || line.contains("alt+m") ||
            line.contains(" = menu") || line.contains("auto mode on") ||
            line.contains(" on ") && line.contains(" via ") && line.contains(" took ")
    }

    private func isBuildStatusLine(_ line: String) -> Bool {
        line.hasPrefix("building for debugging") || line.hasPrefix("build complete!") ||
            line.hasPrefix("built: /") || line.hasPrefix("open it, then grant accessibility permission") ||
            line.hasPrefix("[") && line.contains("] ") && line.contains("build")
    }

    private var statusLineFragments: [String] {
        ["esc to", "ctrl+", "enter to", "? for shortcuts",
         "tokens used", "tokens remaining", "shell"]
    }
}
