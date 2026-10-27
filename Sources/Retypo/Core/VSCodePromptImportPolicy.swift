struct VSCodePromptImportPolicy {
    let enabled: Bool

    func shouldTryAccessibleView(bundleIdentifier: String?) -> Bool {
        enabled && Self.isVSCodeBundleIdentifier(bundleIdentifier)
    }

    static func isVSCodeBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return vscodeBundleIdentifiers.contains(bundleIdentifier)
    }

    static var disabledHint: String {
        " VS Code prompt import is experimental. Enable it in Settings; it uses VS Code Accessible View (Option+F2)."
    }

    private static var vscodeBundleIdentifiers: Set<String> {
        ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.visualstudio.code.oss", "com.vscodium"]
    }
}
