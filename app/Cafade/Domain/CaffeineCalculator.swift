import Foundation

struct CaffeineEstimate: Equatable {
    let typicalMg: Double
    let minMg: Double
    let maxMg: Double

    static let zero = Self(typicalMg: 0, minMg: 0, maxMg: 0)

    var hasRange: Bool {
        abs(maxMg - minMg) >= 0.5
    }

    var displayText: String {
        if hasRange {
            return "\(Int(minMg.rounded()))–\(Int(maxMg.rounded())) mg"
        }
        return CaffeineFormatter.mg(typicalMg)
    }

    var shortDisplayText: String {
        if hasRange {
            return "\(Int(minMg.rounded()))–\(Int(maxMg.rounded()))"
        }
        return "\(Int(typicalMg.rounded()))"
    }
}

enum CaffeineCalculator {
    static func estimate(
        events: [IntakeEvent],
        at date: Date,
        halfLifeHours: Int
    ) -> CaffeineEstimate {
        let halfLife = max(0.5, Double(halfLifeHours))
        var typical = 0.0
        var minimum = 0.0
        var maximum = 0.0

        for event in events where event.consumedAt <= date {
            let elapsedHours = max(0, date.timeIntervalSince(event.consumedAt) / 3600)
            let factor = pow(0.5, elapsedHours / halfLife)
            typical += Double(event.caffeineMg) * factor
            minimum += Double(event.minMg ?? event.caffeineMg) * factor
            maximum += Double(event.maxMg ?? event.caffeineMg) * factor
        }

        return CaffeineEstimate(typicalMg: typical, minMg: minimum, maxMg: maximum)
    }

    static func timeline(
        events: [IntakeEvent],
        centeredAt date: Date,
        halfLifeHours: Int,
        points: Int = 49,
        spanHours: Double = 24
    ) -> [(date: Date, estimate: CaffeineEstimate)] {
        let safePoints = max(2, points)
        let start = date.addingTimeInterval(-(spanHours / 2) * 3600)
        let interval = (spanHours * 3600) / Double(safePoints - 1)
        return (0..<safePoints).map { index in
            let sampleDate = start.addingTimeInterval(Double(index) * interval)
            return (
                sampleDate,
                estimate(events: events, at: sampleDate, halfLifeHours: halfLifeHours)
            )
        }
    }

    static func crossingDate(
        events: [IntakeEvent],
        after date: Date,
        targetMg: Int,
        halfLifeHours: Int
    ) -> Date? {
        guard targetMg >= 0 else { return nil }
        let step: TimeInterval = 5 * 60
        let horizon: TimeInterval = 36 * 3600
        var cursor = date
        while cursor <= date.addingTimeInterval(horizon) {
            if estimate(events: events, at: cursor, halfLifeHours: halfLifeHours).typicalMg <= Double(targetMg) {
                return cursor
            }
            cursor.addTimeInterval(step)
        }
        return nil
    }

    static func dailyTotals(
        events: [IntakeEvent],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [(day: Date, total: Int, highest: Int, last: Date?)] {
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        var cursor = start
        var values: [(Date, Int, Int, Date?)] = []

        while cursor <= end {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let dayEvents = events.filter { $0.consumedAt >= cursor && $0.consumedAt < next }
            values.append(
                (
                    cursor,
                    dayEvents.reduce(0) { $0 + $1.caffeineMg },
                    dayEvents.map(\.caffeineMg).max() ?? 0,
                    dayEvents.map(\.consumedAt).max()
                )
            )
            cursor = next
        }
        return values
    }
}
