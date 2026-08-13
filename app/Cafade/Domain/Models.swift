import Foundation
import SwiftData

enum UnitSystem: String, CaseIterable, Codable, Identifiable {
    case usCustomary
    case metric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usCustomary: "US customary"
        case .metric: "Metric"
        }
    }
}

enum IntakeSourceKind: String, Codable {
    case catalog
    case custom
    case healthKit
}

enum CatalogValueKind: String, Codable, Hashable {
    case exact
    case approximate
    case range

    var label: String {
        switch self {
        case .exact: "Exact"
        case .approximate: "Approximate"
        case .range: "Typical range"
        }
    }
}

struct CaffeineValue: Codable, Equatable, Hashable {
    let kind: CatalogValueKind
    let typicalMg: Int
    let minMg: Int?
    let maxMg: Int?

    static func exact(_ mg: Int) -> Self {
        Self(kind: .exact, typicalMg: mg, minMg: nil, maxMg: nil)
    }

    static func approximate(_ mg: Int) -> Self {
        Self(kind: .approximate, typicalMg: mg, minMg: nil, maxMg: nil)
    }

    static func range(_ minMg: Int, _ maxMg: Int, typical: Int? = nil) -> Self {
        Self(
            kind: .range,
            typicalMg: typical ?? Int((Double(minMg) + Double(maxMg)) / 2.0),
            minMg: minMg,
            maxMg: maxMg
        )
    }

    func scaled(by multiplier: Double) -> Self {
        let scale: (Int) -> Int = { Int((Double($0) * multiplier).rounded()) }
        return Self(
            kind: kind,
            typicalMg: scale(typicalMg),
            minMg: minMg.map(scale),
            maxMg: maxMg.map(scale)
        )
    }

    var displayText: String {
        switch kind {
        case .exact:
            "\(typicalMg) mg"
        case .approximate:
            "~\(typicalMg) mg"
        case .range:
            if let minMg, let maxMg {
                "\(minMg)–\(maxMg) mg"
            } else {
                "~\(typicalMg) mg"
            }
        }
    }
}

struct CatalogDrink: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let marketCode: String
    let brand: String?
    let productName: String
    let variant: String?
    let familyID: String
    let servingLabel: String
    let servingMl: Int
    let value: CaffeineValue
    let sourceURL: String
    let verifiedAt: Date
    let isActive: Bool

    var title: String {
        if let brand, !brand.isEmpty {
            return "\(brand) \(productName)"
        }
        return productName
    }

    var searchText: String {
        [brand, productName, variant, servingLabel]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
    }

    func servingTitle(for unitSystem: UnitSystem) -> String {
        if servingMl <= 0 {
            return servingLabel
        }
        switch unitSystem {
        case .usCustomary:
            return servingLabel
        case .metric:
            return VolumeFormatter.label(ml: servingMl, unitSystem: unitSystem)
        }
    }
}

@Model
final class IntakeEvent: Identifiable {
    @Attribute(.unique) var id: UUID
    var catalogItemID: String?
    var customName: String?
    var caffeineMg: Int
    var minMg: Int?
    var maxMg: Int?
    var quantityMultiplier: Double
    var consumedAt: Date
    var servingNote: String?
    var sourceKindRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        catalogItemID: String? = nil,
        customName: String? = nil,
        caffeineMg: Int,
        minMg: Int? = nil,
        maxMg: Int? = nil,
        quantityMultiplier: Double = 1.0,
        consumedAt: Date,
        servingNote: String? = nil,
        sourceKind: IntakeSourceKind,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.catalogItemID = catalogItemID
        self.customName = customName
        self.caffeineMg = caffeineMg
        self.minMg = minMg
        self.maxMg = maxMg
        self.quantityMultiplier = quantityMultiplier
        self.consumedAt = consumedAt
        self.servingNote = servingNote
        self.sourceKindRaw = sourceKind.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceKind: IntakeSourceKind {
        get { IntakeSourceKind(rawValue: sourceKindRaw) ?? .custom }
        set { sourceKindRaw = newValue.rawValue }
    }

    var isRange: Bool {
        guard let minMg, let maxMg else { return false }
        return minMg != maxMg
    }

    var value: CaffeineValue {
        if let minMg, let maxMg, minMg != maxMg {
            return .range(minMg, maxMg, typical: caffeineMg)
        }
        return .approximate(caffeineMg)
    }
}

@Model
final class UserSettings: Identifiable {
    @Attribute(.unique) var id: String
    var marketCode: String
    var languageCode: String
    var unitSystemRaw: String
    var halfLifeHours: Int
    var dailyTargetMg: Int?
    var typicalBedtimeMinutes: Int?
    var reduceMotionOverride: Bool?
    var healthKitWriteEnabled: Bool

    init(
        id: String = "primary",
        marketCode: String = "US",
        languageCode: String = "en-US",
        unitSystem: UnitSystem = .usCustomary,
        halfLifeHours: Int = 4,
        dailyTargetMg: Int? = nil,
        typicalBedtimeMinutes: Int? = nil,
        reduceMotionOverride: Bool? = nil,
        healthKitWriteEnabled: Bool = false
    ) {
        self.id = id
        self.marketCode = marketCode
        self.languageCode = languageCode
        self.unitSystemRaw = unitSystem.rawValue
        self.halfLifeHours = halfLifeHours
        self.dailyTargetMg = dailyTargetMg
        self.typicalBedtimeMinutes = typicalBedtimeMinutes
        self.reduceMotionOverride = reduceMotionOverride
        self.healthKitWriteEnabled = healthKitWriteEnabled
    }

    var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .usCustomary }
        set { unitSystemRaw = newValue.rawValue }
    }

    var bedtimeDate: Date? {
        guard let typicalBedtimeMinutes else { return nil }
        var components = DateComponents()
        components.hour = typicalBedtimeMinutes / 60
        components.minute = typicalBedtimeMinutes % 60
        return Calendar.current.date(from: components)
    }

    func resetToDefaults() {
        marketCode = "US"
        languageCode = "en-US"
        unitSystem = .usCustomary
        halfLifeHours = 4
        dailyTargetMg = nil
        typicalBedtimeMinutes = nil
        reduceMotionOverride = nil
        healthKitWriteEnabled = false
    }
}

enum VolumeFormatter {
    static func label(ml: Int, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "\(ml) mL"
        case .usCustomary:
            let ounces = Double(ml) / 29.5735
            let rounded = Int(ounces.rounded())
            return "\(rounded) fl oz"
        }
    }
}

enum CaffeineFormatter {
    static func mg(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(max(0, rounded)) mg"
    }

    static func signedMg(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(rounded >= 0 ? "+" : "")\(rounded) mg"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
