import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @EnvironmentObject private var entitlements: EntitlementService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]

    @State private var selectedDays = 7
    @State private var selectedEvent: IntakeEvent?
    @State private var isPaywallPresented = false

    private var userSettings: UserSettings? { settings.first }

    init() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -91, to: .now) ?? .distantPast
        _events = Query(
            filter: #Predicate<IntakeEvent> { $0.consumedAt >= cutoff },
            sort: \IntakeEvent.consumedAt,
            order: .reverse
        )
    }

    private var interval: DateInterval {
        let end = Date.now
        let start = Calendar.current.date(byAdding: .day, value: -(selectedDays - 1), to: Calendar.current.startOfDay(for: end)) ?? end
        return DateInterval(start: start, end: end)
    }

    private var visibleEvents: [IntakeEvent] {
        events.filter { interval.contains($0.consumedAt) }
    }

    private var totals: [(day: Date, total: Int, last: Date?)] {
        CaffeineCalculator.dailyTotals(events: visibleEvents, in: interval)
    }

    private var average: Int {
        guard !totals.isEmpty else { return 0 }
        return Int((Double(totals.reduce(0) { $0 + $1.total }) / Double(totals.count)).rounded())
    }

    private var highest: Int { totals.map(\.total).max() ?? 0 }
    private var lastEvent: IntakeEvent? { visibleEvents.first }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        rangePicker
                        summaryCard
                        insightLinks
                        entriesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityHidden(selectedEvent != nil || isPaywallPresented)
            .navigationDestination(for: HistoryDestination.self) { destination in
                switch destination {
                case .insights:
                    InsightsView()
                case .sleep:
                    SleepComparisonView()
                }
            }
            .sheet(item: $selectedEvent) { event in
                EntryEditorSheet(event: event)
                    .environment(services)
            }
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView()
                    .environmentObject(entitlements)
            }
            .onChange(of: entitlements.isPro) { _, isPro in
                if !isPro { selectedDays = 7 }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LOOKING BACK")
                .font(.caption.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(CafadePalette.accentText)
            Text("YOUR PATTERNS")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("A little context is more useful than a perfect score.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var rangePicker: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { rangeButtons }
            VStack(spacing: 8) { rangeButtons }
        }
        .padding(5)
        .background(CafadePalette.paper.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var rangeButtons: some View {
        rangeButton(title: "7 days", days: 7, isLocked: false)
        rangeButton(title: "30 days", days: 30, isLocked: !entitlements.isPro)
        rangeButton(title: "90 days", days: 90, isLocked: !entitlements.isPro)
    }

    private func rangeButton(title: String, days: Int, isLocked: Bool) -> some View {
        Button {
            if isLocked {
                isPaywallPresented = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedDays = days
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if isLocked { Image(systemName: "lock.fill").font(.caption2) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedDays == days ? CafadePalette.ink : CafadePalette.mist)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(selectedDays == days ? CafadePalette.saffron : .clear, in: Capsule())
        }
        .accessibilityLabel(isLocked ? "\(title), Cafade Pro" : title)
    }

    private var summaryCard: some View {
        CafadeGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("LAST \(selectedDays) DAYS")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(CafadePalette.accentText)
                    Spacer()
                    Image(systemName: "chart.xyaxis.line")
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(CafadePalette.mint)
                }
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 14) { summaryMetrics }
                    } else {
                        HStack(alignment: .top, spacing: 0) { summaryMetrics }
                    }
                }
                if visibleEvents.isEmpty {
                    Text("Log a drink to start building a useful record.")
                        .font(.caption)
                        .foregroundStyle(CafadePalette.mist)
                } else {
                    MiniBarChart(totals: totals)
                        .frame(height: 90)
                }
            }
        }
    }

    @ViewBuilder
    private var summaryMetrics: some View {
        HistoryMetric(title: "Daily average", value: "\(average) mg")
        HistoryMetric(title: "Highest day", value: "\(highest) mg")
        HistoryMetric(title: "Last caffeine", value: lastEvent.map(CaffeineFormatter.time(for:)) ?? "—")
    }

    private var insightLinks: some View {
        VStack(spacing: 10) {
            insightLink(
                title: "Weekly patterns",
                detail: entitlements.isPro ? "See when caffeine tends to arrive." : "Unlock with Cafade Pro.",
                symbol: "waveform.path.ecg",
                color: CafadePalette.lavender
            ) {
                if entitlements.isPro { return .insights }
                isPaywallPresented = true
                return nil
            }
            insightLink(
                title: "Sleep comparison",
                detail: entitlements.isPro ? "Compare your estimate at bedtime." : "Unlock with Cafade Pro.",
                symbol: "moon.stars",
                color: CafadePalette.sky
            ) {
                if entitlements.isPro { return .sleep }
                isPaywallPresented = true
                return nil
            }
        }
    }

    @ViewBuilder
    private func insightLink(
        title: String,
        detail: String,
        symbol: String,
        color: Color,
        action: @escaping () -> HistoryDestination?
    ) -> some View {
        if entitlements.isPro {
            NavigationLink(value: action() ?? .insights) {
                insightRow(title: title, detail: detail, symbol: symbol, color: color)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: { _ = action() }) {
                insightRow(title: title, detail: detail, symbol: symbol, color: color)
            }
            .buttonStyle(.plain)
        }
    }

    private func insightRow(title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.title3)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
            Spacer()
            Image(systemName: entitlements.isPro ? "chevron.right" : "lock.fill")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.mist)
        }
        .padding(16)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            CafadeSectionLabel(eyebrow: "YOUR LOG", title: "Entries", detail: "Tap an entry to edit or delete it.")
            if visibleEvents.isEmpty {
                CafadeGlassCard {
                    CafadeEmptyState(title: "Nothing here yet", detail: "Your saved drinks will appear by day.", symbol: "list.bullet.rectangle")
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedDays, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(CaffeineFormatter.historyDay(group.day))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CafadePalette.mint)
                            ForEach(group.events) { event in
                                Button {
                                    selectedEvent = event
                                } label: {
                                    HistoryEntryRow(event: event, unitSystem: userSettings?.unitSystem ?? .usCustomary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedDays: [(day: Date, events: [IntakeEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleEvents) { calendar.startOfDay(for: $0.consumedAt) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day, default: []].sorted { $0.consumedAt > $1.consumedAt })
        }
    }
}

private enum HistoryDestination: Hashable {
    case insights
    case sleep
}

private struct HistoryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundStyle(CafadePalette.mist)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(CafadePalette.paper)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryEntryRow: View {
    let event: IntakeEvent
    let unitSystem: UnitSystem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(CaffeineFormatter.time(for: event))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(CafadePalette.mist)
                        Spacer()
                        eventValue
                    }
                    eventDescription
                }
            } else {
                HStack(spacing: 12) {
                    Text(CaffeineFormatter.time(for: event))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(CafadePalette.mist)
                        .frame(width: 76, alignment: .leading)
                    eventDescription
                    Spacer()
                    eventValue
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CafadePalette.mist)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(CaffeineCatalog.displayName(for: event)), \(CaffeineCatalog.value(for: event).displayText), \(CaffeineFormatter.time(for: event))")
    }

    private var eventDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(CaffeineCatalog.displayName(for: event))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CafadePalette.paper)
            if let catalogItem = CaffeineCatalog.item(id: event.catalogItemID) {
                Text(catalogItem.servingTitle(for: unitSystem))
                    .font(.caption2)
                    .foregroundStyle(CafadePalette.mist)
            } else if let note = event.servingNote, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }

    private var eventValue: some View {
        Text(CaffeineCatalog.value(for: event).displayText)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(CafadePalette.accentText)
    }

}

private struct MiniBarChart: View {
    let totals: [(day: Date, total: Int, last: Date?)]

    var body: some View {
        let maxValue = max(1, totals.map(\.total).max() ?? 1)
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(totals.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(item.total > 0 ? CafadePalette.saffron : CafadePalette.paper.opacity(0.10))
                        .frame(height: max(5, CGFloat(item.total) / CGFloat(maxValue) * 54))
                    Text(CaffeineFormatter.weekday(item.day, width: .narrow))
                        .font(.caption2)
                        .foregroundStyle(CafadePalette.mist)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
    }
}
