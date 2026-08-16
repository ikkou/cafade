import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var lastDrinkOffset = 0.0

    init() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .distantPast
        _events = Query(
            filter: #Predicate<IntakeEvent> { $0.consumedAt >= cutoff },
            sort: \IntakeEvent.consumedAt,
            order: .reverse
        )
    }

    private var userSettings: UserSettings? { settings.first }
    private var interval: DateInterval {
        DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now,
            end: .now
        )
    }
    private var totals: [(day: Date, total: Int, last: Date?)] {
        CaffeineCalculator.dailyTotals(events: visibleEvents, in: interval)
    }
    private var average: Int {
        guard !totals.isEmpty else { return 0 }
        return Int((Double(totals.reduce(0) { $0 + $1.total }) / Double(totals.count)).rounded())
    }

    private var visibleEvents: [IntakeEvent] {
        events.filter { interval.contains($0.consumedAt) }
    }

    var body: some View {
        ZStack {
            CafadeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    stats
                    weekChart
                    weekdayPattern
                    timeOfDay
                    whatIfCard
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("THE LAST 7 DAYS")
                .font(.caption.weight(.semibold))
                .tracking(1.7)
                .foregroundStyle(CafadePalette.accentText)
            Text("Patterns, not pressure.")
                .font(.system(.title, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("A week is enough to notice a rhythm without turning it into a score.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var stats: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { insightMetrics }
            } else {
                HStack(spacing: 10) { insightMetrics }
            }
        }
    }

    @ViewBuilder
    private var insightMetrics: some View {
        InsightMetric(title: "Daily average", value: "\(average) mg", color: CafadePalette.accentText)
        InsightMetric(title: "Most in a day", value: "\(totals.map(\.total).max() ?? 0) mg", color: CafadePalette.coral)
    }

    private var weekChart: some View {
        let maximum = CGFloat(max(1, totals.map(\.total).max() ?? 1))
        return CafadeGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                CafadeSectionLabel(eyebrow: "BY DAY", title: "Your week")
                VStack(spacing: 12) {
                    ForEach(Array(totals.enumerated()), id: \.offset) { _, item in
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(CaffeineFormatter.weekday(item.day))
                                    Spacer()
                                    Text("\(item.total) mg")
                                        .monospacedDigit()
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(CafadePalette.paper)
                                GeometryReader { proxy in
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(item.total == 0 ? CafadePalette.paper.opacity(0.08) : CafadePalette.saffron)
                                        .frame(width: proxy.size.width * CGFloat(item.total) / maximum)
                                }
                                .frame(height: 12)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Text(CaffeineFormatter.weekday(item.day))
                                    .font(.caption)
                                    .foregroundStyle(CafadePalette.mist)
                                    .frame(width: 34, alignment: .leading)
                                GeometryReader { proxy in
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(item.total == 0 ? CafadePalette.paper.opacity(0.08) : CafadePalette.saffron)
                                        .frame(width: proxy.size.width * CGFloat(item.total) / maximum)
                                }
                                .frame(height: 12)
                                Text("\(item.total)")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(CafadePalette.paper)
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private var timeOfDay: some View {
        CafadeGlassCard(tint: CafadePalette.lavender.opacity(0.06)) {
            VStack(alignment: .leading, spacing: 14) {
                CafadeSectionLabel(eyebrow: "WHEN", title: "Your first and last")
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 12) { boundaryMetrics }
                    } else {
                        HStack { boundaryMetrics }
                    }
                }
                Text("The median first and last log time on days with caffeine. These are observations, not recommendations.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }

    @ViewBuilder
    private var boundaryMetrics: some View {
        PatternMetric(title: "Typical first", value: typicalBoundaryTime(first: true) ?? "—")
        PatternMetric(title: "Typical last", value: typicalBoundaryTime(first: false) ?? "—")
    }

    private var weekdayPattern: some View {
        let values = weekdayTotals
        let maximum = max(1, values.map(\.total).max() ?? 1)

        return CafadeGlassCard(tint: CafadePalette.mint.opacity(0.045)) {
            VStack(alignment: .leading, spacing: 14) {
                CafadeSectionLabel(eyebrow: "RHYTHM", title: "By weekday")
                Text("A quick view of which days carry the most caffeine in your log.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.label)
                                Spacer()
                                Text("\(item.total) mg")
                                    .monospacedDigit()
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(CafadePalette.paper)
                        }
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 7) {
                                GeometryReader { proxy in
                                    VStack {
                                        Spacer(minLength: 0)
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(item.total == 0 ? CafadePalette.paper.opacity(0.08) : CafadePalette.mint)
                                            .frame(height: max(8, proxy.size.height * CGFloat(item.total) / CGFloat(maximum)))
                                    }
                                }
                                .frame(height: 72)
                                Text(item.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(CafadePalette.mist)
                                Text("\(item.total)")
                                    .font(.caption2.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(CafadePalette.paper)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var weekdayTotals: [(label: String, total: Int)] {
        let calendar = Calendar.current
        var totals = Array(repeating: 0, count: 7)
        for event in visibleEvents {
            let weekday = calendar.component(.weekday, from: event.consumedAt)
            guard totals.indices.contains(weekday - 1) else { continue }
            totals[weekday - 1] += event.caffeineMg
        }

        var englishCalendar = calendar
        englishCalendar.locale = CaffeineFormatter.appLocale
        return englishCalendar.shortWeekdaySymbols.enumerated().map { index, label in
            (label: label, total: totals[index])
        }
    }

    private var whatIfCard: some View {
        CafadeGlassCard(tint: CafadePalette.sky.opacity(0.06)) {
            VStack(alignment: .leading, spacing: 14) {
                CafadeSectionLabel(eyebrow: "WHAT IF", title: "Move your last drink")
                Text("See how the current estimate changes if the last drink happened earlier or later.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                Slider(value: $lastDrinkOffset, in: -2...2, step: 0.5)
                    .tint(CafadePalette.sky)
                    .accessibilityLabel("Move your last drink")
                    .accessibilityValue(offsetLabel)
                HStack {
                    Text(offsetLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CafadePalette.sky)
                    Spacer()
                    Text(scenarioEstimate.displayText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(CafadePalette.paper)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var scenarioEstimate: CaffeineEstimate {
        let now = Date.now
        let halfLife = userSettings?.halfLifeHours ?? 4
        guard let last = visibleEvents.max(by: { $0.consumedAt < $1.consumedAt }), lastDrinkOffset != 0 else {
            return CaffeineCalculator.estimate(events: visibleEvents, at: now, halfLifeHours: halfLife)
        }
        let baseline = CaffeineCalculator.estimate(
            events: visibleEvents.filter { $0.id != last.id },
            at: now,
            halfLifeHours: halfLife
        )
        let shiftedContribution = CaffeineCalculator.estimate(
            value: last.value,
            consumedAt: last.consumedAt.addingTimeInterval(lastDrinkOffset * 3600),
            at: now,
            halfLifeHours: halfLife
        )
        return CaffeineCalculator.combining(baseline, shiftedContribution)
    }

    private var offsetLabel: String {
        guard lastDrinkOffset != 0 else { return "As logged" }
        let totalMinutes = Int((abs(lastDrinkOffset) * 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let amount: String
        if hours > 0, minutes > 0 {
            amount = "\(hours)h \(minutes)m"
        } else if hours > 0 {
            amount = "\(hours)h"
        } else {
            amount = "\(minutes)m"
        }
        return "\(amount) \(lastDrinkOffset < 0 ? "earlier" : "later")"
    }

    private func typicalBoundaryTime(first: Bool) -> String? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleEvents) { calendar.startOfDay(for: $0.consumedAt) }
        let minutes = grouped.values.compactMap { dayEvents -> Int? in
            guard let event = first
                ? dayEvents.min(by: { $0.consumedAt < $1.consumedAt })
                : dayEvents.max(by: { $0.consumedAt < $1.consumedAt })
            else { return nil }
            let components = calendar.dateComponents([.hour, .minute], from: event.consumedAt)
            guard let hour = components.hour, let minute = components.minute else { return nil }
            return hour * 60 + minute
        }.sorted()

        guard !minutes.isEmpty else { return nil }
        let middle = minutes.count / 2
        let median = minutes.count.isMultiple(of: 2)
            ? Int((Double(minutes[middle - 1] + minutes[middle]) / 2).rounded())
            : minutes[middle]
        return CaffeineFormatter.clock(minutes: median)
    }
}

private struct InsightMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(CafadePalette.mist)
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
    }
}

private struct PatternMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(CafadePalette.mist)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(CafadePalette.paper)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
