import Foundation
import WidgetKit

enum CafadeWidgetConstants {
    static let kind = "CafadeCurrentEstimateWidget"
    static let appGroupIdentifier = "group.com.oneshotstar.cafade"
}

struct CafadeWidgetEstimate: Equatable, Sendable {
    let typicalMg: Double
    let minMg: Double
    let maxMg: Double

    var hasRange: Bool {
        abs(maxMg - minMg) >= 0.5
    }

    var amountText: String {
        if hasRange {
            return "\(Int(minMg.rounded()))–\(Int(maxMg.rounded()))"
        }
        return "\(Int(typicalMg.rounded()))"
    }

    var accessibilityText: String {
        if hasRange {
            return "\(Int(minMg.rounded())) to \(Int(maxMg.rounded())) milligrams"
        }
        return "\(Int(typicalMg.rounded())) milligrams"
    }
}

struct CafadeWidgetEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let catalogItemID: String?
    let caffeineMg: Int
    let minMg: Int?
    let maxMg: Int?
    let valueKindRaw: String
    let sourceKindRaw: String
    let consumedAt: Date

    var quickDrink: CafadeWidgetQuickDrink {
        CafadeWidgetQuickDrink(
            id: CafadeWidgetQuickDrink.identifier(
                name: name,
                catalogItemID: catalogItemID,
                caffeineMg: caffeineMg,
                minMg: minMg,
                maxMg: maxMg
            ),
            name: name,
            catalogItemID: catalogItemID,
            caffeineMg: caffeineMg,
            minMg: minMg,
            maxMg: maxMg,
            valueKindRaw: valueKindRaw,
            sourceKindRaw: sourceKindRaw
        )
    }
}

struct CafadeWidgetQuickDrink: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let catalogItemID: String?
    let caffeineMg: Int
    let minMg: Int?
    let maxMg: Int?
    let valueKindRaw: String
    let sourceKindRaw: String

    static func identifier(
        name: String,
        catalogItemID: String?,
        caffeineMg: Int,
        minMg: Int?,
        maxMg: Int?
    ) -> String {
        let source = catalogItemID ?? name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return [source, String(caffeineMg), minMg.map(String.init) ?? "", maxMg.map(String.init) ?? ""]
            .joined(separator: "|")
    }

    static let defaults: [Self] = [
        Self(
            id: "cafade.default.brewed-coffee",
            name: "Brewed coffee",
            catalogItemID: nil,
            caffeineMg: 95,
            minMg: nil,
            maxMg: nil,
            valueKindRaw: "approximate",
            sourceKindRaw: "custom"
        ),
        Self(
            id: "cafade.default.espresso",
            name: "Espresso",
            catalogItemID: nil,
            caffeineMg: 64,
            minMg: nil,
            maxMg: nil,
            valueKindRaw: "approximate",
            sourceKindRaw: "custom"
        ),
        Self(
            id: "cafade.default.energy-drink",
            name: "Energy drink",
            catalogItemID: nil,
            caffeineMg: 160,
            minMg: nil,
            maxMg: nil,
            valueKindRaw: "approximate",
            sourceKindRaw: "custom"
        )
    ]
}

struct CafadeWidgetSnapshot: Codable, Equatable, Sendable {
    var events: [CafadeWidgetEvent]
    var quickDrinks: [CafadeWidgetQuickDrink]
    var halfLifeHours: Int
    var updatedAt: Date

    static let empty = Self(
        events: [],
        quickDrinks: CafadeWidgetQuickDrink.defaults,
        halfLifeHours: 4,
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    func estimate(at date: Date) -> CafadeWidgetEstimate {
        let halfLife = max(0.5, Double(halfLifeHours))
        var typical = 0.0
        var minimum = 0.0
        var maximum = 0.0

        for event in events where event.consumedAt <= date {
            let elapsedHours = max(0, date.timeIntervalSince(event.consumedAt) / 3_600)
            let factor = pow(0.5, elapsedHours / halfLife)
            typical += Double(event.caffeineMg) * factor
            minimum += Double(event.minMg ?? event.caffeineMg) * factor
            maximum += Double(event.maxMg ?? event.caffeineMg) * factor
        }

        return CafadeWidgetEstimate(typicalMg: typical, minMg: minimum, maxMg: maximum)
    }

    mutating func record(_ event: CafadeWidgetEvent, now: Date = .now) {
        events.removeAll { $0.id == event.id }
        events.append(event)

        let cutoff = now.addingTimeInterval(-14 * 24 * 3_600)
        events = events
            .filter { $0.consumedAt >= cutoff }
            .sorted { $0.consumedAt > $1.consumedAt }

        let quickDrink = event.quickDrink
        quickDrinks.removeAll { $0.id == quickDrink.id }
        quickDrinks.insert(quickDrink, at: 0)
        quickDrinks = Array(quickDrinks.prefix(3))
        updatedAt = now
    }

    mutating func normalize() {
        halfLifeHours = [2, 4, 6, 8].contains(halfLifeHours) ? halfLifeHours : 4
        quickDrinks = Array(quickDrinks.filter { (1...1_000).contains($0.caffeineMg) }.prefix(3))

        for fallback in CafadeWidgetQuickDrink.defaults where quickDrinks.count < 3 {
            guard !quickDrinks.contains(where: { $0.id == fallback.id }) else { continue }
            quickDrinks.append(fallback)
        }
    }
}

enum CafadeWidgetStore {
    private static let snapshotKey = "cafade.widget.snapshot.v1"
    private static let pendingEventsKey = "cafade.widget.pending-events.v1"
    private static let lock = NSLock()

    static func loadSnapshot() -> CafadeWidgetSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return loadSnapshotUnlocked()
    }

    static func saveSnapshot(_ snapshot: CafadeWidgetSnapshot) {
        lock.lock()
        var merged = snapshot
        for event in loadPendingEventsUnlocked() {
            merged.record(event)
        }
        merged.normalize()
        saveSnapshotUnlocked(merged)
        lock.unlock()
        WidgetCenter.shared.reloadTimelines(ofKind: CafadeWidgetConstants.kind)
    }

    static func logQuickDrink(id: String, at date: Date = .now) -> CafadeWidgetEvent? {
        lock.lock()
        var snapshot = loadSnapshotUnlocked()
        guard let drink = snapshot.quickDrinks.first(where: { $0.id == id }) else {
            lock.unlock()
            return nil
        }

        let event = CafadeWidgetEvent(
            id: UUID(),
            name: drink.name,
            catalogItemID: drink.catalogItemID,
            caffeineMg: drink.caffeineMg,
            minMg: drink.minMg,
            maxMg: drink.maxMg,
            valueKindRaw: drink.valueKindRaw,
            sourceKindRaw: drink.sourceKindRaw,
            consumedAt: date
        )

        var pending = loadPendingEventsUnlocked()
        pending.removeAll { $0.id == event.id }
        pending.append(event)
        savePendingEventsUnlocked(pending)

        snapshot.record(event, now: date)
        snapshot.normalize()
        saveSnapshotUnlocked(snapshot)
        lock.unlock()
        WidgetCenter.shared.reloadTimelines(ofKind: CafadeWidgetConstants.kind)
        return event
    }

    static func pendingEvents() -> [CafadeWidgetEvent] {
        lock.lock()
        defer { lock.unlock() }
        return loadPendingEventsUnlocked().sorted { $0.consumedAt < $1.consumedAt }
    }

    static func acknowledgePendingEvents(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        lock.lock()
        let remaining = loadPendingEventsUnlocked().filter { !ids.contains($0.id) }
        savePendingEventsUnlocked(remaining)
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        defaults?.removeObject(forKey: snapshotKey)
        defaults?.removeObject(forKey: pendingEventsKey)
        lock.unlock()
        WidgetCenter.shared.reloadTimelines(ofKind: CafadeWidgetConstants.kind)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: CafadeWidgetConstants.appGroupIdentifier)
    }

    private static func loadSnapshotUnlocked() -> CafadeWidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              var snapshot = try? JSONDecoder().decode(CafadeWidgetSnapshot.self, from: data) else {
            return .empty
        }
        snapshot.normalize()
        return snapshot
    }

    private static func saveSnapshotUnlocked(_ snapshot: CafadeWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    private static func loadPendingEventsUnlocked() -> [CafadeWidgetEvent] {
        guard let data = defaults?.data(forKey: pendingEventsKey) else { return [] }
        return (try? JSONDecoder().decode([CafadeWidgetEvent].self, from: data)) ?? []
    }

    private static func savePendingEventsUnlocked(_ events: [CafadeWidgetEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults?.set(data, forKey: pendingEventsKey)
    }
}
