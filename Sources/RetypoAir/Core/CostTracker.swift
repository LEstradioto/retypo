import Foundation

/// All cost / usage / pricing state, isolated from AppState.
///
/// Owns: pricing table (keyed by provider::model), the last call's cost
/// snapshot, accumulated session and day costs, and the rolling usage
/// ledger. Knows how to convert a `TokenUsage` into a USD cost given
/// the pricing table.
///
/// Persists: pricing.json + usage-ledger.json via PersistedFile.
@MainActor
final class CostTracker: ObservableObject {
    @Published var pricing: [String: ModelPricing]
    @Published var lastCost: CostSnapshot = CostSnapshot(usage: .zero, costUSD: nil)
    @Published var sessionCostUSD: Double = 0
    @Published var dayCostUSD: Double = 0
    @Published var usageLedger: [UsageLedgerEntry]
    /// Set when the last call ran through a subscription CLI. Those have no
    /// per-token price, and a bare "$—" reads like the pricing table broke.
    @Published private(set) var lastCallWasSubscription = false

    init(initialPricing: [String: ModelPricing], initialUsageLedger: [UsageLedgerEntry]) {
        self.pricing = initialPricing
        self.usageLedger = initialUsageLedger
        self.dayCostUSD = Self.costToday(from: initialUsageLedger)
    }

    var lastCostLabel: String { lastCostIsSubscription ? "subscription" : formatCost(lastCost.costUSD) }

    /// A priced entry still wins: someone who fills in pricing for a CLI model
    /// wants the estimate they asked for.
    var lastCostIsSubscription: Bool { lastCallWasSubscription && lastCost.costUSD == nil }
    var sessionCostLabel: String { formatCost(sessionCostUSD) }
    var dayCostLabel: String { formatCost(dayCostUSD) }

    /// Update last/session/day totals from one LLM call's usage. Returns the
    /// computed cost (nil if no pricing entry exists for that model).
    @discardableResult
    func recordUsage(provider: ProviderKind, model: String, usage: TokenUsage) -> Double? {
        let cost = computeCost(provider: provider, model: model, usage: usage)
        lastCost = CostSnapshot(usage: usage, costUSD: cost)
        lastCallWasSubscription = provider.usesLocalCLI
        if let cost {
            sessionCostUSD += cost
            dayCostUSD += cost
        }
        return cost
    }

    func appendLedgerEntry(provider: ProviderKind, model: String, usage: TokenUsage, costUSD: Double?) {
        let entry = UsageLedgerEntry(provider: provider, model: model, usage: usage, costUSD: costUSD)
        usageLedger.insert(entry, at: 0)
        usageLedger = Array(usageLedger.prefix(500))
        UsageLedgerStore.save(usageLedger)
    }

    func computeCost(provider: ProviderKind, model: String, usage: TokenUsage) -> Double? {
        let key = PricingStore.key(provider: provider, model: model)
        guard let p = pricing[key] else { return nil }
        let inputCost = Double(usage.inputTokens) / 1_000_000 * p.inputPerMillion
        let outputCost = Double(usage.outputTokens) / 1_000_000 * p.outputPerMillion
        return inputCost + outputCost
    }

    func formatCost(_ value: Double?) -> String {
        guard let value else { return "$—" }
        if value == 0 { return "$0.0000" }
        if value < 0.0001 { return String(format: "$%.6f", value) }
        return String(format: "$%.4f", value)
    }

    func mergePricingDefaults(for provider: ProviderKind, models: [ProviderModel]) {
        var changed = false
        for model in models {
            let key = PricingStore.key(provider: provider, model: model.id)
            if let value = model.pricing ?? DefaultPricing.pricing(provider: provider, modelID: model.id), pricing[key] != value {
                pricing[key] = value
                changed = true
            }
        }
        for (key, value) in DefaultPricing.exact where pricing[key] != value {
            pricing[key] = value
            changed = true
        }
        if changed { PricingStore.save(pricing) }
    }

    /// Fill pricing keys we have never seen from the models.dev snapshot.
    /// Only missing keys are inserted: provider list data, bundled defaults,
    /// and anything the user typed in Settings always win. Returns how many
    /// keys were added, for the refresh status line.
    @discardableResult
    func mergeFetchedPricing(_ fetched: [String: ModelPricing]) -> Int {
        let merged = Self.mergingFetchedPricing(fetched, into: pricing)
        pricing = merged.pricing
        if merged.inserted > 0 { PricingStore.save(pricing) }
        return merged.inserted
    }

    nonisolated static func mergingFetchedPricing(
        _ fetched: [String: ModelPricing],
        into pricing: [String: ModelPricing]
    ) -> (pricing: [String: ModelPricing], inserted: Int) {
        var pricing = pricing
        var inserted = 0
        for (key, value) in fetched where pricing[key] == nil {
            pricing[key] = value
            inserted += 1
        }
        return (pricing, inserted)
    }

    func pricingBindingValue(for provider: ProviderKind, model: String) -> ModelPricing {
        pricing[PricingStore.key(provider: provider, model: model)] ?? .zero
    }

    func setPricing(_ value: ModelPricing, provider: ProviderKind, model: String) {
        pricing[PricingStore.key(provider: provider, model: model)] = value
        PricingStore.save(pricing)
    }

    static func costToday(from entries: [UsageLedgerEntry]) -> Double {
        let calendar = Calendar.current
        return entries.reduce(0) { total, entry in
            guard calendar.isDateInToday(entry.timestamp), let cost = entry.costUSD else { return total }
            return total + cost
        }
    }
}
