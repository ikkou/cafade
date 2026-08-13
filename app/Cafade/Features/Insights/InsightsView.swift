import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query(sort: \IntakeEvent.consumedAt, order: .reverse) private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]
    @State private var lastDrinkOffset = 0.0

    private var userSettings: UserSettings? { settings.first }
    private var interval: DateInterval {
        DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now,
            end: .now
        )
    }
    private var totals: [(day: Date, total: Int, highest: Int, last: Date?)] {
        CaffeineCalculator.dailyTotals(events: events.filter { interval.contains($0.consumedAt) }, in: interval)
    }
    private var average: Int {
        let values = totals.map(\.total).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
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
                .foregroundStyle(CafadePalette.saffron)
            Text("Patterns, not pressure.")
                .font(.system(.title, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("A week is enough to notice a rhythm without turning it into a score.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            InsightMetric(title: "Daily average", value: "\(average) mg", color: CafadePalette.saffron)
            InsightMetric(title: "Most in a day", value: "\(totals.map(\.total).max() ?? 0) mg", color: CafadePalette.coral)
        }
    }

    private var weekChart: some View {
        CafadeGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                CafadeSectionLabel(eyebrow: "BY DAY", title: "Your week")
                VStack(spacing: 12) {
                    ForEach(Array(totals.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 12) {
                            Text(item.day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(CafadePalette.mist)
                                .frame(width: 34, alignment: .leading)
                            GeometryReader { proxy in
                                let maxValue = CGFloat(max(1, totals.map(\.total).max() ?? 1))
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(item.total == 0 ? CafadePalette.paper.opacity(0.08) : CafadePalette.saffron)
                                    .frame(width: proxy.size.width * CGFloat(item.total) / maxValue)
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

    private var timeOfDay: some View {
        CafadeGlassCard(tint: CafadePalette.lavender.opacity(0.06)) {
            VStack(alignment: .leading, spacing: 14) {
                CafadeSectionLabel(eyebrow: "WHEN", title: "Your first and last")
                let first = events.filter { interval.contains($0.consumedAt) }.min { $0.consumedAt < $1.consumedAt }
                let last = events.filter { interval.contains($0.consumedAt) }.max { $0.consumedAt < $1.consumedAt }
                HStack {
                    PatternMetric(title: "First caffeine", value: first.map { CaffeineFormatter.time($0.consumedAt) } ?? "—")
                    PatternMetric(title: "Last caffeine", value: last.map { CaffeineFormatter.time($0.consumedAt) } ?? "—")
                }
                Text("These are observations from your log, not recommendations.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
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

    private var weekdayTotals: [(label: String, total: Int)] {
        let calendar = Calendar.current
        var totals = Array(repeating: 0, count: 7)
        for event in events where interval.contains(event.consumedAt) {
            let weekday = calendar.component(.weekday, from: event.consumedAt)
            guard totals.indices.contains(weekday - 1) else { continue }
            totals[weekday - 1] += event.caffeineMg
        }

        return calendar.shortWeekdaySymbols.enumerated().map { index, label in
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
                HStack {
                    Text(lastDrinkOffset == 0 ? "As logged" : lastDrinkOffset < 0 ? "\(abs(Int(lastDrinkOffset)))h earlier" : "\(Int(lastDrinkOffset))h later")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CafadePalette.sky)
                    Spacer()
                    Text(scenarioEstimate.displayText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(CafadePalette.paper)
                }
            }
        }
    }

    private var scenarioEstimate: CaffeineEstimate {
        let selectedEvents = events.filter { interval.contains($0.consumedAt) }
        guard let last = selectedEvents.max(by: { $0.consumedAt < $1.consumedAt }), lastDrinkOffset != 0 else {
            return CaffeineCalculator.estimate(events: selectedEvents, at: .now, halfLifeHours: userSettings?.halfLifeHours ?? 4)
        }
        let shifted = IntakeEvent(
            id: last.id,
            catalogItemID: last.catalogItemID,
            customName: last.customName,
            caffeineMg: last.caffeineMg,
            minMg: last.minMg,
            maxMg: last.maxMg,
            quantityMultiplier: last.quantityMultiplier,
            consumedAt: last.consumedAt.addingTimeInterval(lastDrinkOffset * 3600),
            servingNote: last.servingNote,
            sourceKind: last.sourceKind
        )
        let replaced = selectedEvents.map { $0.id == last.id ? shifted : $0 }
        return CaffeineCalculator.estimate(events: replaced, at: .now, halfLifeHours: userSettings?.halfLifeHours ?? 4)
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
