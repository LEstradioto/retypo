import Foundation
import AppKit

enum MainTheme: String, CaseIterable, Identifiable, Codable {
    case glass
    case dark
    case system
    case monokai
    case tokyoNight
    case catppuccin

    var id: String { rawValue }
    /// `glass` is the historic default look and stays as the Light theme.
    /// The legacy `lighter` value decodes to it (see `init(from:)`).
    var displayName: String {
        switch self {
        case .glass: "Light"
        case .dark: "Dark"
        case .system: "System"
        case .monokai: "Monokai"
        case .tokyoNight: "Tokyo Night"
        case .catppuccin: "Catppuccin"
        }
    }

    /// Explicit palette for the curated presets; `nil` follows the system
    /// NSColors (Light / Dark / System).
    var definition: ThemeDefinition? {
        switch self {
        case .monokai: .monokai
        case .tokyoNight: .tokyoNight
        case .catppuccin: .catppuccin
        case .glass, .dark, .system: nil
        }
    }

    /// Window appearance override. `nil` follows the macOS system setting.
    /// Applied to the main + auxiliary panels so the theme picker works
    /// regardless of system appearance (NSColor-based palette follows the
    /// window's appearance automatically).
    var nsAppearance: NSAppearance? {
        switch self {
        case .glass: NSAppearance(named: .aqua)
        case .system: nil
        case .dark, .monokai, .tokyoNight, .catppuccin: NSAppearance(named: .darkAqua)
        }
    }

    /// Renamed raw values keep decoding to their successor.
    private static let renamedThemes: [String: MainTheme] = ["lighter": .glass]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self(rawValue: raw) ?? Self.renamedThemes[raw] ?? .glass
    }
}

struct RetypoSettings: Codable, Equatable {
    var provider: ProviderKind = .anthropic
    var modelByProvider: [ProviderKind: String] = [
        .anthropic: "claude-haiku-4-5-20251001"
    ]
    var autoCopy: Bool = true
    var alwaysOnTop: Bool = false
    var nativeSpellcheck: Bool = true
    var panelFrame: PanelFrame = PanelFrame()
    var currentActionID: String = "correct"
    var mainTheme: MainTheme = .glass
    var shortcutByAction: [String: String] = [
        "correct": "cmd+1",
        "improve": "cmd+2",
        "translate": "cmd+3",
        "simplify": "cmd+4",
        "summarize": "cmd+5",
        "bullets": "cmd+6",
        "better-way": "cmd+7",
        "tweet-fit": "cmd+8",
        "variations-3": "cmd+9",
        "respond-3-ways": "cmd+0"
    ]
    var shortcutByModel: [String: String] = [:]
    var acceptedModelIDsByProvider: [ProviderKind: [String]] = [:]
    var nextModelShortcut: String = "cmd+opt+]"
    var previousModelShortcut: String = "cmd+opt+["
    var followActiveScreenOnShow: Bool = true
    var historyLimit: Int = 10
    var terminalPromptImportEnabled: Bool = true
    var experimentalVSCodeAccessibleViewImport: Bool = true
    var smartPasteEnabled: Bool = true
    var smartPasteShortcut: String = "cmd+shift+v"
    var windowOpacity: Double = 1.0
    var fontColorHex: String? = nil
    /// Empty means the built-in hardened preamble in PromptTemplates.
    var systemPreamble: String = ""
    /// Experimental: live translation card under the input box.
    var liveTranslationEnabled: Bool = false
    var liveTranslationTarget: String = "pt-BR"
    var liveTranslationEngine: LiveTranslationEngine = .auto
    /// Height of the mode prompt editor in the Cmd+D picker, set by dragging
    /// its resize grip.
    var modePromptHeight: Double = 140
    static let modePromptHeightRange: ClosedRange<CGFloat> = 64...640

    init() {}

    func selectedModel(for provider: ProviderKind) -> String? {
        let value = modelByProvider[provider]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    func modelShortcutKey(provider: ProviderKind, modelID: String) -> String {
        "\(provider.rawValue)::\(modelID)"
    }

    enum CodingKeys: String, CodingKey {
        case provider, modelByProvider, autoCopy, alwaysOnTop, nativeSpellcheck, panelFrame, currentActionID, mainTheme, shortcutByAction, shortcutByModel, acceptedModelIDsByProvider, nextModelShortcut, previousModelShortcut, followActiveScreenOnShow, historyLimit, terminalPromptImportEnabled, experimentalVSCodeAccessibleViewImport, smartPasteEnabled, smartPasteShortcut, windowOpacity, fontColorHex, systemPreamble, liveTranslationEnabled, liveTranslationTarget, liveTranslationEngine, modePromptHeight
    }

    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try decodeDisplay(from: container)
        try decodeAppearance(from: container)
        try decodeShortcuts(from: container)
        try decodeImports(from: container)
    }

    private mutating func decodeDisplay(from container: KeyedDecodingContainer<CodingKeys>) throws {
        provider = try container.decodeIfPresent(ProviderKind.self, forKey: .provider) ?? provider
        modelByProvider = try container.decodeIfPresent([ProviderKind: String].self, forKey: .modelByProvider) ?? modelByProvider
        autoCopy = try container.decodeIfPresent(Bool.self, forKey: .autoCopy) ?? autoCopy
        alwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? alwaysOnTop
        nativeSpellcheck = try container.decodeIfPresent(Bool.self, forKey: .nativeSpellcheck) ?? nativeSpellcheck
        panelFrame = try container.decodeIfPresent(PanelFrame.self, forKey: .panelFrame) ?? panelFrame
        systemPreamble = try container.decodeIfPresent(String.self, forKey: .systemPreamble) ?? systemPreamble
        modePromptHeight = try container.decodeIfPresent(Double.self, forKey: .modePromptHeight) ?? modePromptHeight
    }

    private mutating func decodeAppearance(from container: KeyedDecodingContainer<CodingKeys>) throws {
        currentActionID = try container.decodeIfPresent(String.self, forKey: .currentActionID) ?? currentActionID
        mainTheme = try container.decodeIfPresent(MainTheme.self, forKey: .mainTheme) ?? mainTheme
        windowOpacity = try container.decodeIfPresent(Double.self, forKey: .windowOpacity) ?? windowOpacity
        fontColorHex = try container.decodeIfPresent(String.self, forKey: .fontColorHex) ?? fontColorHex
    }

    private mutating func decodeShortcuts(from container: KeyedDecodingContainer<CodingKeys>) throws {
        if let shortcuts = try container.decodeIfPresent([String: String].self, forKey: .shortcutByAction) {
            shortcutByAction.merge(shortcuts) { _, new in new }
        }
        shortcutByModel = try container.decodeIfPresent([String: String].self, forKey: .shortcutByModel) ?? shortcutByModel
        acceptedModelIDsByProvider = try container.decodeIfPresent([ProviderKind: [String]].self, forKey: .acceptedModelIDsByProvider) ?? acceptedModelIDsByProvider
        nextModelShortcut = try container.decodeIfPresent(String.self, forKey: .nextModelShortcut) ?? nextModelShortcut
        previousModelShortcut = try container.decodeIfPresent(String.self, forKey: .previousModelShortcut) ?? previousModelShortcut
    }

    private mutating func decodeImports(from container: KeyedDecodingContainer<CodingKeys>) throws {
        followActiveScreenOnShow = try container.decodeIfPresent(Bool.self, forKey: .followActiveScreenOnShow) ?? followActiveScreenOnShow
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? historyLimit
        terminalPromptImportEnabled = try container.decodeIfPresent(Bool.self, forKey: .terminalPromptImportEnabled) ?? terminalPromptImportEnabled
        experimentalVSCodeAccessibleViewImport = try container.decodeIfPresent(Bool.self, forKey: .experimentalVSCodeAccessibleViewImport) ?? experimentalVSCodeAccessibleViewImport
        smartPasteEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartPasteEnabled) ?? smartPasteEnabled
        smartPasteShortcut = try container.decodeIfPresent(String.self, forKey: .smartPasteShortcut) ?? smartPasteShortcut
        liveTranslationEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveTranslationEnabled) ?? liveTranslationEnabled
        liveTranslationTarget = try container.decodeIfPresent(String.self, forKey: .liveTranslationTarget) ?? liveTranslationTarget
        liveTranslationEngine = try container.decodeIfPresent(LiveTranslationEngine.self, forKey: .liveTranslationEngine) ?? liveTranslationEngine
    }
}

enum SettingsStore {
    /// Back-compat alias; new code should use `AppFiles.directory`.
    static var directory: URL { AppFiles.directory }

    private static let file = PersistedFile<RetypoSettings>(
        url: AppFiles.url("settings.json"),
        fallback: RetypoSettings()
    )

    static func load() -> RetypoSettings { file.load() }
    static func save(_ settings: RetypoSettings) { file.save(settings) }
}
