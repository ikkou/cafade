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

    func isValid(maximumMg: Int) -> Bool {
        guard typicalMg > 0, typicalMg <= maximumMg else { return false }

        switch kind {
        case .exact, .approximate:
            return minMg == nil && maxMg == nil
        case .range:
            guard let minMg, let maxMg else { return false }
            return minMg > 0
                && minMg <= typicalMg
                && typicalMg <= maxMg
                && maxMg <= maximumMg
        }
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
    var valueKindRaw: String?
    var quantityMultiplier: Double
    var consumedAt: Date
    var consumedTimeZoneIdentifier: String?
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
        valueKind: CatalogValueKind? = nil,
        quantityMultiplier: Double = 1.0,
        consumedAt: Date,
        consumedTimeZoneIdentifier: String = TimeZone.current.identifier,
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
        self.valueKindRaw = valueKind?.rawValue
        self.quantityMultiplier = quantityMultiplier
        self.consumedAt = consumedAt
        self.consumedTimeZoneIdentifier = consumedTimeZoneIdentifier
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

    var valueKind: CatalogValueKind {
        get {
            if let valueKindRaw, let value = CatalogValueKind(rawValue: valueKindRaw) {
                return value
            }
            return isRange ? .range : .approximate
        }
        set { valueKindRaw = newValue.rawValue }
    }

    var value: CaffeineValue {
        if valueKind == .range, let minMg, let maxMg {
            return CaffeineValue(kind: .range, typicalMg: caffeineMg, minMg: minMg, maxMg: maxMg)
        }
        return CaffeineValue(kind: valueKind, typicalMg: caffeineMg, minMg: nil, maxMg: nil)
    }

    var healthKitSyncVersion: Int64 {
        max(1, Int64((updatedAt.timeIntervalSince1970 * 1_000).rounded()))
    }

    func markUpdated(at date: Date = .now) {
        let candidate = max(1, Int64((date.timeIntervalSince1970 * 1_000).rounded()))
        let nextVersion = max(candidate, healthKitSyncVersion + 1)
        updatedAt = Date(timeIntervalSince1970: Double(nextVersion) / 1_000)
    }
}

@Model
final class UserSettings: Identifiable {
    static let supportedHalfLifeHours = [2, 4, 6, 8]

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

    @discardableResult
    func normalizeForCurrentVersion() -> Bool {
        var changed = false

        if marketCode != "US" {
            marketCode = "US"
            changed = true
        }
        if languageCode != "en-US" {
            languageCode = "en-US"
            changed = true
        }
        if UnitSystem(rawValue: unitSystemRaw) == nil {
            unitSystem = .usCustomary
            changed = true
        }
        if !Self.supportedHalfLifeHours.contains(halfLifeHours) {
            halfLifeHours = 4
            changed = true
        }
        if let dailyTargetMg {
            if dailyTargetMg <= 0 {
                self.dailyTargetMg = nil
                changed = true
            } else if dailyTargetMg > CaffeineCalculator.customEntryMaximumMg {
                self.dailyTargetMg = CaffeineCalculator.customEntryMaximumMg
                changed = true
            }
        }
        if let typicalBedtimeMinutes, !(0..<24 * 60).contains(typicalBedtimeMinutes) {
            self.typicalBedtimeMinutes = nil
            changed = true
        }

        return changed
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
    static let appLocale = Locale(identifier: "en-US")

    static func mg(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(max(0, rounded)) mg"
    }

    static func signedMg(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(rounded >= 0 ? "+" : "")\(rounded) mg"
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(appLocale).hour().minute())
    }

    static func time(for event: IntakeEvent) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: appLocale)
        if let identifier = event.consumedTimeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            style.timeZone = timeZone
        }
        return event.consumedAt.formatted(style)
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.locale(appLocale).year().month(.abbreviated).day())
    }

    static func date(for event: IntakeEvent) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: appLocale)
        if let identifier = event.consumedTimeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            style.timeZone = timeZone
        }
        return event.consumedAt.formatted(style)
    }

    static func fullDay(_ date: Date) -> String {
        date.formatted(.dateTime.locale(appLocale).weekday(.wide).month(.wide).day())
    }

    static func historyDay(_ date: Date) -> String {
        date.formatted(.dateTime.locale(appLocale).weekday(.wide).month(.abbreviated).day())
    }

    static func weekday(_ date: Date, width: Date.FormatStyle.Symbol.Weekday = .abbreviated) -> String {
        date.formatted(.dateTime.locale(appLocale).weekday(width))
    }

    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(appLocale).year().month(.wide).day())
    }

    static func clock(minutes: Int) -> String {
        let normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = normalized / 60
        components.minute = normalized % 60
        guard let date = components.date else { return "—" }
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: appLocale, timeZone: TimeZone(secondsFromGMT: 0)!)
        )
    }
}
