import SwiftData
import SwiftUI

struct SleepComparisonView: View {
    @Query private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]

    private var userSettings: UserSettings? { settings.first }

    init() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        _events = Query(
            filter: #Predicate<IntakeEvent> { $0.consumedAt >= cutoff },
            sort: \IntakeEvent.consumedAt,
            order: .reverse
        )
    }

    var body: some View {
        ZStack {
            CafadeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    comparisonCard
                    note
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Sleep comparison")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR BEDTIME")
                .font(.caption.weight(.semibold))
                .tracking(1.7)
                .foregroundStyle(CafadePalette.accentText)
            Text("Make room for sleep.")
                .font(.system(.title, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("Cafade uses the bedtime you choose in Settings. It does not read sleep data.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    @ViewBuilder
    private var comparisonCard: some View {
        if let bedtimeMinutes = userSettings?.typicalBedtimeMinutes {
            let bedtime = nextBedtime(minutes: bedtimeMinutes)
            let estimate = CaffeineCalculator.estimate(events: events, at: bedtime, halfLifeHours: userSettings?.halfLifeHours ?? 4)
            CafadeGlassCard(tint: CafadePalette.sky.opacity(0.07)) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("AT \(CaffeineFormatter.time(bedtime).uppercased())")
                            .font(.caption.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(CafadePalette.sky)
                        Spacer()
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(CafadePalette.lavender)
                    }
                    CaffeineValueLabel(estimate: estimate, size: 48)
                    Text("Estimated caffeine around your typical bedtime")
                        .font(.subheadline)
                        .foregroundStyle(CafadePalette.mist)
                    Divider().overlay(CafadePalette.line)
                    HStack {
                        Text("Half-life")
                        Spacer()
                        Text("\(userSettings?.halfLifeHours ?? 4) hours")
                    }
                    .font(.subheadline)
                    .foregroundStyle(CafadePalette.mist)
                }
            }
        } else {
            CafadeGlassCard {
                CafadeEmptyState(title: "Choose a bedtime", detail: "Set your typical bedtime in Settings to compare the estimate.", symbol: "moon.zzz")
            }
        }
    }

    private var note: some View {
        Text("This comparison is a planning view, not a sleep or safety guarantee. Individual responses to caffeine vary.")
            .font(.caption)
            .foregroundStyle(CafadePalette.mist)
    }

    private func nextBedtime(minutes: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = minutes / 60
        components.minute = minutes % 60
        let today = Calendar.current.date(from: components) ?? .now
        if today > .now {
            return today
        }
        return Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
