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

struct CaffeineCurveMarker: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let estimate: CaffeineEstimate
}

enum CaffeineCalculator {
    static let generalDailyReferenceMg = 400
    static let gentleNudgeThresholdMg = 450
    static let customEntryMaximumMg = 1_000
    static let customEntryMinimumMg = 1
    static let customNameMaximumLength = 80
    static let servingNoteMaximumLength = 120
    static let dailyReferenceURL = URL(string: "https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much")!
    static let cardiovascularStatementURL = URL(string: "https://professional.heart.org/en/science-news/caffeine-and-cardiovascular-disease/top-things-to-know")!

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

    static func estimate(
        value: CaffeineValue,
        consumedAt: Date,
        at date: Date,
        halfLifeHours: Int
    ) -> CaffeineEstimate {
        guard consumedAt <= date else { return .zero }
        let elapsedHours = max(0, date.timeIntervalSince(consumedAt) / 3600)
        let factor = pow(0.5, elapsedHours / max(0.5, Double(halfLifeHours)))
        return CaffeineEstimate(
            typicalMg: Double(value.typicalMg) * factor,
            minMg: Double(value.minMg ?? value.typicalMg) * factor,
            maxMg: Double(value.maxMg ?? value.typicalMg) * factor
        )
    }

    static func combining(_ lhs: CaffeineEstimate, _ rhs: CaffeineEstimate) -> CaffeineEstimate {
        adding(lhs, rhs)
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
        let sortedEvents = events.sorted { $0.consumedAt < $1.consumedAt }
        var nextEventIndex = sortedEvents.partitioningIndex { $0.consumedAt > start }
        var previousDate = start
        var running = estimate(events: sortedEvents, at: start, halfLifeHours: halfLifeHours)
        var values: [(date: Date, estimate: CaffeineEstimate)] = [(start, running)]

        for index in 1..<safePoints {
            let sampleDate = start.addingTimeInterval(Double(index) * interval)
            running = decayed(running, from: previousDate, to: sampleDate, halfLifeHours: halfLifeHours)

            while nextEventIndex < sortedEvents.count,
                  sortedEvents[nextEventIndex].consumedAt <= sampleDate {
                let event = sortedEvents[nextEventIndex]
                let contribution = estimate(events: [event], at: sampleDate, halfLifeHours: halfLifeHours)
                running = adding(running, contribution)
                nextEventIndex += 1
            }

            values.append((sampleDate, running))
            previousDate = sampleDate
        }

        return values
    }

    static func crossingDate(
        events: [IntakeEvent],
        after date: Date,
        targetMg: Int,
        halfLifeHours: Int
    ) -> Date? {
        guard targetMg > 0 else { return nil }
        let current = estimate(events: events, at: date, halfLifeHours: halfLifeHours).typicalMg
        guard current > Double(targetMg) else { return date }

        let hours = max(0.5, Double(halfLifeHours)) * log2(current / Double(targetMg))
        guard hours.isFinite, hours >= 0 else { return nil }
        return date.addingTimeInterval(hours * 3600)
    }

    static func curveMarkers(
        events: [IntakeEvent],
        in interval: DateInterval,
        halfLifeHours: Int
    ) -> [CaffeineCurveMarker] {
        let sortedEvents = events
            .filter { $0.consumedAt <= interval.end }
            .sorted { $0.consumedAt < $1.consumedAt }
        var running = CaffeineEstimate.zero
        var previousDate = sortedEvents.first?.consumedAt ?? interval.start
        var markers: [CaffeineCurveMarker] = []

        for event in sortedEvents {
            running = decayed(running, from: previousDate, to: event.consumedAt, halfLifeHours: halfLifeHours)
            running = adding(
                running,
                CaffeineEstimate(
                    typicalMg: Double(event.caffeineMg),
                    minMg: Double(event.minMg ?? event.caffeineMg),
                    maxMg: Double(event.maxMg ?? event.caffeineMg)
                )
            )
            if interval.contains(event.consumedAt) || event.consumedAt == interval.end {
                markers.append(.init(id: event.id, date: event.consumedAt, estimate: running))
            }
            previousDate = event.consumedAt
        }

        return markers
    }

    static func dailyTotals(
        events: [IntakeEvent],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [(day: Date, total: Int, last: Date?)] {
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let grouped = Dictionary(
            grouping: events.filter { $0.consumedAt >= start && $0.consumedAt < interval.end },
            by: { calendar.startOfDay(for: $0.consumedAt) }
        )
        var cursor = start
        var values: [(Date, Int, Date?)] = []

        while cursor <= end {
            let dayEvents = grouped[cursor, default: []]
            values.append(
                (
                    cursor,
                    dayEvents.reduce(0) { $0 + $1.caffeineMg },
                    dayEvents.map(\.consumedAt).max()
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else {
                break
            }
            cursor = next
        }
        return values
    }

    static func loggedTotalMg(
        on date: Date,
        events: [IntakeEvent],
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return events
            .filter { $0.consumedAt >= start && $0.consumedAt < end }
            .reduce(0) { $0 + $1.caffeineMg }
    }

    private static func decayed(
        _ estimate: CaffeineEstimate,
        from start: Date,
        to end: Date,
        halfLifeHours: Int
    ) -> CaffeineEstimate {
        let elapsedHours = max(0, end.timeIntervalSince(start) / 3600)
        let factor = pow(0.5, elapsedHours / max(0.5, Double(halfLifeHours)))
        return CaffeineEstimate(
            typicalMg: estimate.typicalMg * factor,
            minMg: estimate.minMg * factor,
            maxMg: estimate.maxMg * factor
        )
    }

    private static func adding(_ lhs: CaffeineEstimate, _ rhs: CaffeineEstimate) -> CaffeineEstimate {
        CaffeineEstimate(
            typicalMg: lhs.typicalMg + rhs.typicalMg,
            minMg: lhs.minMg + rhs.minMg,
            maxMg: lhs.maxMg + rhs.maxMg
        )
    }
}

private extension Array {
    func partitioningIndex(where belongsInSecondPartition: (Element) -> Bool) -> Index {
        var lower = startIndex
        var upper = endIndex

        while lower != upper {
            let distance = self.distance(from: lower, to: upper)
            let middle = index(lower, offsetBy: distance / 2)
            if belongsInSecondPartition(self[middle]) {
                upper = middle
            } else {
                lower = index(after: middle)
            }
        }
        return lower
    }
}
