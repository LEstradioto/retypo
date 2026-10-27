extension AppDelegate {
    func logTextCandidateSummary(_ candidates: [String], includeApplicationTree: Bool) {
        let maxLength = candidates.map(\.count).max() ?? 0
        DebugLog.log("AX text candidates tree=\(includeApplicationTree) count=\(candidates.count) maxLen=\(maxLength)")
    }

    func logElementCandidateSummary(_ candidates: [String], label: String) {
        let maxLength = candidates.map(\.count).max() ?? 0
        let markerCount = candidates.filter { PromptBufferExtractor().prompt(from: $0) != nil }.count
        DebugLog.log("AX \(label) candidates count=\(candidates.count) maxLen=\(maxLength) promptLike=\(markerCount)")
    }
}
