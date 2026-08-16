import Foundation

// The catalog is bundled JSON so adding a product or market does not require
// changing calculation, persistence, or SwiftUI code.
enum CaffeineCatalog {
    static let items: [CatalogDrink] = loadBundledCatalog()

    static let suggestedIDs = [
        "starbucks.cold-brew.grande",
        "starbucks.americano.grande",
        "generic.brewed-coffee",
        "redbull.original.8-4",
        "diet-coke.original.12",
        "generic.green-tea"
    ]

    static func item(id: String?) -> CatalogDrink? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    static func suggested(marketCode: String = "US") -> [CatalogDrink] {
        suggestedIDs.compactMap(item(id:))
            .filter { $0.isActive && $0.marketCode == marketCode }
    }

    static func search(_ query: String, marketCode: String = "US") -> [CatalogDrink] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return suggested(marketCode: marketCode) }
        return items.filter {
            $0.isActive
                && $0.marketCode == marketCode
                && $0.searchText.contains(normalized)
        }
    }

    static func variants(for familyID: String, marketCode: String = "US") -> [CatalogDrink] {
        items.filter { $0.isActive && $0.marketCode == marketCode && $0.familyID == familyID }
            .sorted { $0.servingMl < $1.servingMl }
    }

    static func value(for event: IntakeEvent) -> CaffeineValue {
        if event.valueKindRaw != nil {
            return event.value
        }
        if let catalog = item(id: event.catalogItemID) {
            return CaffeineValue(
                kind: catalog.value.kind,
                typicalMg: event.caffeineMg,
                minMg: event.minMg,
                maxMg: event.maxMg
            )
        }
        return event.value
    }

    static func validationErrors(in catalog: [CatalogDrink] = items) -> [String] {
        var errors: [String] = []
        let duplicateIDs = Dictionary(grouping: catalog, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        errors.append(contentsOf: duplicateIDs.map { "Duplicate catalog ID: \($0)" })

        for item in catalog {
            if item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Missing catalog ID")
            }
            if item.marketCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Missing market code: \(item.id)")
            }
            if item.productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Missing product name: \(item.id)")
            }
            if item.familyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Missing family ID: \(item.id)")
            }
            if item.servingLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.servingMl <= 0 {
                errors.append("Invalid serving: \(item.id)")
            }
            let sourceURL = URL(string: item.sourceURL)
            if sourceURL?.scheme?.lowercased() != "https" || sourceURL?.host?.isEmpty != false {
                errors.append("Invalid source URL: \(item.id)")
            }
            if item.verifiedAt > Date.now.addingTimeInterval(24 * 3600) {
                errors.append("Future verification date: \(item.id)")
            }
            if !item.value.isValid(maximumMg: CaffeineCalculator.customEntryMaximumMg) {
                errors.append("Invalid caffeine value: \(item.id)")
            }
        }
        return errors
    }

    static func displayName(for event: IntakeEvent) -> String {
        if let catalog = item(id: event.catalogItemID) {
            return catalog.title
        }
        return event.customName ?? "Custom drink"
    }

    private static func loadBundledCatalog() -> [CatalogDrink] {
        guard let url = Bundle(for: CatalogBundleToken.self)
            .url(forResource: "CaffeineCatalog", withExtension: "json")
        else {
            assertionFailure("CaffeineCatalog.json is missing from the Cafade bundle.")
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([CatalogDrink].self, from: Data(contentsOf: url))
            let errors = validationErrors(in: decoded)
            guard errors.isEmpty else {
                assertionFailure("Invalid caffeine catalog: \(errors.joined(separator: "; "))")
                return []
            }
            return decoded
        } catch {
            assertionFailure("CaffeineCatalog.json could not be decoded: \(error)")
            return []
        }
    }
}

private final class CatalogBundleToken: NSObject { }
