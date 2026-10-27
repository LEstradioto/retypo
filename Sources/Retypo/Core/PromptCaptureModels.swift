enum PromptCaptureKind: Equatable {
    case accessibilityTextBuffer
    case claudeDividerComposer
    case vscodeAccessibleView

    func sourceName(applicationName: String) -> String {
        switch self {
        case .accessibilityTextBuffer: return "terminal prompt in \(applicationName)"
        case .claudeDividerComposer: return "Claude prompt in \(applicationName)"
        case .vscodeAccessibleView: return "VS Code prompt via Accessible View in \(applicationName)"
        }
    }
}

struct PromptCaptureCandidate: Equatable {
    let text: String
    let kind: PromptCaptureKind
}
