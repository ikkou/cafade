import SwiftData
import SwiftUI

struct TodayView: View {
    private let openSettings: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query(sort: \IntakeEvent.consumedAt) private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var isLogSheetPresented = false
    @State private var isShareCardPresented = false
    @State private var showingHealthPrompt = false
    @State private var healthErrorMessage: String?
    @AppStorage("cafade.hasShownHealthPrompt") private var hasShownHealthPrompt = false

    private var userSettings: UserSettings? { settings.first }
    private var now: Date { .now }

    init(openSettings: @escaping () -> Void = {}) {
        self.openSettings = openSettings
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        estimateCard
                        curveCard
                        targetCard
                        recentSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
                logButton
                    .padding(.bottom, 70)
            }
            .background(CafadeBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isLogSheetPresented) {
                LogCaffeineSheet()
                    .environment(services)
            }
            .sheet(isPresented: $isShareCardPresented) {
                ShareCardSheet(snapshot: shareSnapshot)
            }
            .alert("Save your caffeine to Apple Health?", isPresented: $showingHealthPrompt) {
                Button("Connect Apple Health") {
                    Task { await connectHealthKit() }
                }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Cafade can add your logged caffeine to Apple Health. This is optional.")
            }
            .alert(
                "Apple Health",
                isPresented: Binding(
                    get: { healthErrorMessage != nil },
                    set: { if !$0 { healthErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { healthErrorMessage = nil }
            } message: {
                Text(healthErrorMessage ?? "")
            }
            .task {
                await maybeShowHealthPrompt()
            }
            .onChange(of: events.count) { oldCount, newCount in
                guard newCount > oldCount else { return }
                Task { await maybeShowHealthPrompt() }
            }
        }
    }

    private var logButton: some View {
        Button {
            isLogSheetPresented = true
        } label: {
            Text("LOG CAFFEINE")
        }
        .buttonStyle(CafadePrimaryButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(CafadePalette.background.opacity(0.98))
        .accessibilityIdentifier("today.logCaffeine")
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CafadePalette.saffron)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text("TODAY")
                    .font(.system(size: 38, weight: .medium, design: .serif))
                    .foregroundStyle(CafadePalette.paper)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    isShareCardPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CafadePalette.paper)
                        .frame(width: 44, height: 44)
                        .background(CafadePalette.paper.opacity(0.08), in: Circle())
                        .overlay(Circle().stroke(CafadePalette.line, lineWidth: 1))
                }
                .accessibilityLabel("Share your day")

                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(CafadePalette.paper)
                        .frame(width: 44, height: 44)
                        .background(CafadePalette.paper.opacity(0.08), in: Circle())
                        .overlay(Circle().stroke(CafadePalette.line, lineWidth: 1))
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var estimateCard: some View {
        let estimate = currentEstimate
        return CafadeGlassCard(tint: CafadePalette.saffron.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("CURRENT ESTIMATE")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.6)
                        .foregroundStyle(CafadePalette.saffron)
                    Spacer()
                    CafadePill(title: "NOW", color: CafadePalette.mint)
                }

                ZStack {
                    CafadeCaffeineOrb(estimate: estimate)
                        .frame(maxWidth: .infinity)
                        .frame(height: 168)
                        .padding(.horizontal, 18)
                    VStack(spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 7) {
                            Text(estimate.shortDisplayText)
                                .font(.system(size: 50, weight: .regular, design: .serif))
                                .monospacedDigit()
                                .foregroundStyle(Color.white)
                            Text("mg")
                                .font(.system(size: 19, weight: .medium, design: .serif))
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                        Text(estimate.maxMg < 1 ? "waiting for your first log" : "fading slowly  ↘")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                }
                .padding(.vertical, 6)

                HStack(spacing: 10) {
                    TodayMetricChip(
                        label: "LAST DRINK",
                        value: latestEvent.map { CaffeineFormatter.time($0.consumedAt) } ?? "—",
                        tint: CafadePalette.saffron
                    )
                    TodayMetricChip(
                        label: "SLEEP TARGET",
                        value: userSettings?.bedtimeDate?.formatted(date: .omitted, time: .shortened) ?? "—",
                        tint: CafadePalette.lavender
                    )
                }
            }
        }
    }

    private var curveCard: some View {
        CafadeGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                CafadeSectionLabel(
                    eyebrow: "YOUR DAY",
                    title: "Watch it fade",
                    detail: "A living estimate, shaped by every drink you log."
                )
                CaffeineCurveView(
                    events: events,
                    now: now,
                    halfLifeHours: userSettings?.halfLifeHours ?? 4,
                    reduceMotion: systemReduceMotion
                )
            }
        }
    }

    @ViewBuilder
    private var targetCard: some View {
        if let target = userSettings?.dailyTargetMg {
            let current = currentEstimate.typicalMg
            let crossing = CaffeineCalculator.crossingDate(
                events: events,
                after: now,
                targetMg: target,
                halfLifeHours: userSettings?.halfLifeHours ?? 4
            )
            CafadeGlassCard(tint: CafadePalette.mint.opacity(0.06)) {
                HStack(spacing: 14) {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(CafadePalette.mint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Personal target")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CafadePalette.paper)
                        if current <= Double(target) {
                            Text("Below your personal target now")
                        } else if let crossing {
                            Text("Below your personal target by \(crossing.formatted(date: .omitted, time: .shortened))")
                        } else {
                            Text("Your estimate stays above \(target) mg today")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                    Spacer()
                    Text("\(target) mg")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(CafadePalette.mint)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CafadeSectionLabel(eyebrow: "RECENT", title: "Your day")
            }

            if events.isEmpty {
                CafadeGlassCard {
                    CafadeEmptyState(
                        title: "Start with one drink",
                        detail: "Coffee, tea, soda, energy drinks, or a custom caffeine amount.",
                        symbol: "cup.and.saucer"
                    )
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(events.sorted(by: { $0.consumedAt > $1.consumedAt }).prefix(5)) { event in
                        RecentEventRow(event: event) {
                            repeatEvent(event)
                        }
                    }
                }
            }
        }
    }

    private var currentEstimate: CaffeineEstimate {
        CaffeineCalculator.estimate(
            events: events,
            at: now,
            halfLifeHours: userSettings?.halfLifeHours ?? 4
        )
    }

    private var latestEvent: IntakeEvent? {
        events.max(by: { $0.consumedAt < $1.consumedAt })
    }

    private var shareSnapshot: CafadeShareSnapshot {
        let todayEvents = events.filter { Calendar.current.isDate($0.consumedAt, inSameDayAs: now) }
        return CafadeShareSnapshot(
            date: now,
            estimate: currentEstimate,
            events: todayEvents,
            halfLifeHours: userSettings?.halfLifeHours ?? 4
        )
    }

    private func estimateSubtitle(for estimate: CaffeineEstimate) -> String {
        if events.isEmpty {
            return "Log a drink to see your estimate."
        }
        if estimate.maxMg < 1 {
            return "No caffeine is estimated right now."
        }
        return "Based on your logged drinks"
    }

    private func estimateDetail(for estimate: CaffeineEstimate) -> String {
        if events.isEmpty {
            return "Nothing logged yet"
        }
        if estimate.maxMg < 1 {
            return "Your saved history is still here"
        }
        return "The line updates as your day changes"
    }

    private func repeatEvent(_ event: IntakeEvent) {
        let value = CaffeineCatalog.value(for: event)
        let settings = userSettings ?? AppServices.ensureSettings(in: modelContext)
        _ = services.log(
            value: value,
            catalogItemID: event.catalogItemID,
            customName: event.customName,
            // `value(for:)` already represents the amount that was logged.
            // Applying the original multiplier again would double-scale repeats.
            multiplier: 1.0,
            consumedAt: .now,
            servingNote: event.servingNote,
            sourceKind: event.sourceKind,
            context: modelContext,
            settings: settings
        )
    }

    private func maybeShowHealthPrompt() async {
        guard !hasShownHealthPrompt, !events.isEmpty else { return }
        guard services.healthKit.isAvailable else { return }
        try? await Task.sleep(for: .milliseconds(550))
        guard !hasShownHealthPrompt else { return }
        hasShownHealthPrompt = true
        showingHealthPrompt = true
    }

    private func connectHealthKit() async {
        let settings = userSettings ?? AppServices.ensureSettings(in: modelContext)
        do {
            try await services.requestHealthKitAndSync(events: events, settings: settings, context: modelContext)
        } catch {
            healthErrorMessage = error.localizedDescription
        }
    }
}

private struct TodayMetricChip: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(CafadePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(CafadePalette.background.opacity(0.64), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CafadePalette.line, lineWidth: 1)
        }
    }
}

private struct RecentEventRow: View {
    let event: IntakeEvent
    let repeatAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(CaffeineCatalog.displayName(for: event))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                    .lineLimit(1)
                Text(CaffeineFormatter.time(event.consumedAt))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(CafadePalette.mist)
            }
            Spacer()
            Text(CaffeineCatalog.value(for: event).displayText)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(CafadePalette.saffron)
            Button("Repeat", action: repeatAction)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CafadePalette.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(CafadePalette.mint.opacity(0.12), in: Capsule())
                .accessibilityLabel("Repeat \(CaffeineCatalog.displayName(for: event)) now")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CafadePalette.line, lineWidth: 1)
        }
    }
}
