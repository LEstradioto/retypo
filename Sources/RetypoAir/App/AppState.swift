import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    let footerFocusItemCount = 9

    @Published var settings: RetypoSettings
    @Published var inputText: String = ""
    @Published var correctedText: String = ""
    @Published var outputText: String = ""
    @Published var status: String = "Ready"
    /// Full text of the last failure. `status` is shown on a single truncated
    /// footer line, so the readable version lives here for tooltip and copy.
    @Published var lastErrorDetail: String?
    @Published var diffText: String = ""
    @Published var inlineHighlightRanges: [NSRange] = []
    @Published var showSettings = false
    @Published var selectedLauncherModeIndex = 0
    @Published var actions: [EditAction]
    @Published var history: [HistoryEntry]
    @Published var draftSnapshots: [DraftSnapshot]
    @Published var candidateResults: [CandidateResult] = []
    @Published var showCandidateOverlay = false
    @Published var selectedCandidateIndex = 0
    @Published var wordsPerMinute: Double = 0
    @Published var wordsChangedLast = 0
    @Published var footerFocusIndex: Int? = nil
    @Published var pendingImport: PendingImport?
    @Published var canUndoEditorChange = false
    @Published var canRedoEditorChange = false
    /// Live instruction text for the Freeform mode. Populated only while
    /// the user has Freeform selected; sent as the system instruction at run.
    @Published var freeformInstruction: String = ""
    /// Incremented on every Freeform-prompt open. The view watches this
    /// counter to re-fire focus into the text field on subsequent shows
    /// (SwiftUI's `@FocusState` won't auto-refocus by itself when the
    /// containing panel is just orderFront'd again).
    @Published var freeformPromptShowID: Int = 0

    let cost: CostTracker
    let llm = LLMSession()

    weak var host: PanelHost?

    let debouncer = Debouncer()
    let draftHistoryDebouncer = Debouncer()
    var lastAutoSubmittedHash: Int?
    var suppressNextInputChange = false
    var typingStartedAt: Date?
    /// Last time `updateTypingStats` saw a change. Used to detect long pauses
    /// and reset the WPM session so the number doesn't keep falling while you
    /// step away from the keyboard.
    var lastTypingUpdate: Date?
    var editor = EditorEngine(limit: 50)
    private var cancellables = Set<AnyCancellable>()

    init(settings: RetypoSettings) {
        self.settings = settings
        self.actions = EditActionStore.load()
        self.history = HistoryStore.load()
        let (loadedPricing, pricingChanged) = Self.loadedPricing()
        self.cost = CostTracker(initialPricing: loadedPricing, initialUsageLedger: UsageLedgerStore.load())
        self.draftSnapshots = DraftSnapshotStore.load()
        self.inputText = DraftStore.load()
        if pricingChanged { PricingStore.save(loadedPricing) }
        rebroadcastCostChanges()
    }

    private static func loadedPricing() -> (pricing: [String: ModelPricing], changed: Bool) {
        var loaded = PricingStore.load()
        var changed = false
        for (key, value) in DefaultPricing.exact where loaded[key] != value {
            loaded[key] = value
            changed = true
        }
        return (loaded, changed)
    }

    private func rebroadcastCostChanges() {
        for source in [cost.objectWillChange.eraseToAnyPublisher(), llm.objectWillChange.eraseToAnyPublisher()] {
            source.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
        }
    }


    var selectedProvider: ProviderKind {
        get { settings.provider }
        set {
            settings.provider = newValue
            saveSettings()
            Task { await refreshModelsIfPossible() }
        }
    }

    var selectedModel: String? {
        settings.selectedModel(for: settings.provider)
    }

    /// Auto-run stays off for the CLI providers: every call costs ~7s and
    /// thousands of tokens of subscription quota, so firing on each typing
    /// pause would drain the plan. Enter still runs the current mode.
    var autoRunEnabled: Bool {
        settings.autoCorrect && !settings.provider.usesLocalCLI
    }

    var enabledActions: [EditAction] {
        let enabled = actions.filter(\.isEnabled)
        return enabled.isEmpty ? actions : enabled
    }

    var currentAction: EditAction {
        enabledActions.first { $0.id == settings.currentActionID } ?? enabledActions.first ?? EditAction.defaults[0]
    }

    var modelLabel: String {
        selectedModel ?? "No model"
    }

    var navigableModels: [ProviderModel] {
        let models = llm.modelsByProvider[settings.provider] ?? []
        let accepted = Set(settings.acceptedModelIDsByProvider[settings.provider] ?? [])
        guard !accepted.isEmpty else { return models }
        return models.filter { accepted.contains($0.id) }
    }

    func setSelectedModel(_ model: String, provider: ProviderKind? = nil) {
        if let provider { settings.provider = provider }
        settings.modelByProvider[settings.provider] = model
        status = "Model: \(model)"
        saveSettings()
    }

    func setCurrentAction(_ actionID: String) {
        guard enabledActions.contains(where: { $0.id == actionID }) || actions.contains(where: { $0.id == actionID }) else { return }
        settings.currentActionID = actionID
        saveSettings()
    }

    func requestHide() {
        host?.requestHide()
    }

    func toggleCandidateOverlay() {
        // Always open in launcher mode (mode picker). Multi-candidate flows
        // (run-all-modes) populate `candidateResults` themselves; we used to
        // auto-wrap the leftover diff into a single fake card, but that
        // showed stale state and blocked re-entry to Freeform.
        setCandidateOverlayVisible(!showCandidateOverlay)
    }

    func setCandidateOverlayVisible(_ visible: Bool) {
        showCandidateOverlay = visible
        host?.setCandidatesVisible(visible)
    }

    func requestSettings() {
        host?.requestSettings()
    }
}
