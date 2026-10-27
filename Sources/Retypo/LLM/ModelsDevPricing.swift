import Foundation

/// Cost table from models.dev — free endpoint, no key.
///
/// `GET https://models.dev/api.json` returns one entry per provider:
/// `{ "<provider>": { "models": { "<model>": { "cost": { "input": USD/1M,
/// "output": USD/1M } } } } }`, which maps 1:1 onto `ModelPricing`.
/// Models without a cost object (e.g. audio-only) are skipped, as are
/// providers with no `ProviderKind` (subscription CLIs live there too).
enum ModelsDevPricing {
    static let endpoint = URL(staticString: "https://models.dev/api.json")

    static func pricingByKey(from data: Data) throws -> [String: ModelPricing] {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var result: [String: ModelPricing] = [:]
        for (providerID, providerValue) in root {
            guard let provider = ProviderKind(rawValue: providerID) else { continue }
            let models = (providerValue as? [String: Any])?["models"] as? [String: Any] ?? [:]
            for (modelID, modelValue) in models {
                guard let pricing = pricingIn((modelValue as? [String: Any])?["cost"]) else { continue }
                result[PricingStore.key(provider: provider, model: modelID)] = pricing
            }
        }
        return result
    }

    static func fetchSnapshot() async throws -> [String: ModelPricing] {
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        return try pricingByKey(from: data)
    }

    private static func pricingIn(_ cost: Any?) -> ModelPricing? {
        guard let cost = cost as? [String: Any],
              let input = number(cost["input"]),
              let output = number(cost["output"]) else { return nil }
        return ModelPricing(inputPerMillion: input, outputPerMillion: output)
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }
}
