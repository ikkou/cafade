import SwiftData
import SwiftUI

struct TodayView: View {
    private let isActive: Bool
    private let openSettings: () -> Void
    private let openLog: () -> Void
    private let onLogged: (IntakeMutationOutcome) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShareCardPresented = false
    @State private var showingHealthPrompt = false
    @State private var healthErrorMessage: String?
    @State private var operationErrorMessage: String?
    @State private var currentTime = Date.now
    @AppStorage("cafade.hasShownHealthPrompt") private var hasShownHealthPrompt = false

    private var userSettings: UserSettings? { settings.first }
    private var now: Date { currentTime }
    private var shouldAnimateOrb: Bool {
        isActive
            && !isShareCardPresented
            && !showingHealthPrompt
            && healthErrorMessage == nil
            && operationErrorMessage == nil
    }

    init(
        isActive: Bool = true,
        openSettings: @escaping () -> Void = {},
        openLog: @escaping () -> Void = {},
        onLogged: @escaping (IntakeMutationOutcome) -> Void = { _ in }
    ) {
        self.isActive = isActive
        self.openSettings = openSettings
        self.openLog = openLog
        self.onLogged = onLogged
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        _events = Query(
            filter: #Predicate<IntakeEvent> { $0.consumedAt >= cutoff },
            sort: \IntakeEvent.consumedAt,
            order: .reverse
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityLogButton
                    }
                    estimateCard
                    curveCard
                    targetCard
                    dailyGuidanceCard
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                // Keep the final row scrollable above the floating log control.
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(CafadeBackground())
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityHidden(isShareCardPresented)
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
            .alert(
                "Could not log caffeine",
                isPresented: Binding(
                    get: { operationErrorMessage != nil },
                    set: { if !$0 { operationErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { operationErrorMessage = nil }
            } message: {
                Text(operationErrorMessage ?? "Please try again.")
            }
            .task {
                await maybeShowHealthPrompt()
            }
            .task(id: isActive && scenePhase == .active) {
                guard isActive, scenePhase == .active else { return }
                currentTime = .now
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    currentTime = .now
                }
            }
            .onChange(of: events.count) { oldCount, newCount in
                currentTime = .now
                guard newCount > oldCount else { return }
                Task { await maybeShowHealthPrompt() }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                headerTitle
                headerActions
            }
        } else {
            HStack(alignment: .bottom) {
                headerTitle
                Spacer()
                headerActions
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(CaffeineFormatter.fullDay(now))
                .font(.caption.weight(.semibold))
                .foregroundStyle(CafadePalette.accentText)
                .textCase(.uppercase)
                .tracking(1.2)
            Text("TODAY")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                isShareCardPresented = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(CafadePalette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .tint(CafadePalette.surface)
            .accessibilityLabel("Share your day")

            Button(action: openSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(CafadePalette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .tint(CafadePalette.surface)
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("today.openSettings")
        }
    }

    private var estimateCard: some View {
        let estimate = currentEstimate
        return CafadeGlassCard(tint: CafadePalette.saffron.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 0) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CURRENT ESTIMATE")
                            .font(.caption2.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(CafadePalette.accentText)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        CafadePill(title: "NOW", color: CafadePalette.mint)
                    }
                } else {
                    HStack {
                        Text("CURRENT ESTIMATE")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(CafadePalette.accentText)
                        Spacer()
                        CafadePill(title: "NOW", color: CafadePalette.mint)
                    }
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 8) {
                        CafadeCaffeineOrb(estimate: estimate, isActive: shouldAnimateOrb)
                            .frame(maxWidth: .infinity)
                            .frame(height: 132)
                        estimateLabel(estimate, color: CafadePalette.ink, usesSemanticFont: true)
                    }
                    .padding(.vertical, 8)
                } else {
                    ZStack {
                        CafadeCaffeineOrb(estimate: estimate, isActive: shouldAnimateOrb)
                            .frame(maxWidth: .infinity)
                            .frame(height: 168)
                            .padding(.horizontal, 18)
                        estimateLabel(
                            estimate,
                            color: estimate.typicalMg > 0 ? .white : CafadePalette.ink,
                            usesSemanticFont: false
                        )
                    }
                    .padding(.vertical, 6)
                }

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { metricChips }
                    } else {
                        HStack(spacing: 10) { metricChips }
                    }
                }
            }
        }
    }

    private var accessibilityLogButton: some View {
        Button(action: openLog) {
            Label("Log caffeine", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CafadeSecondaryButtonStyle())
        .accessibilityIdentifier("today.logCaffeine")
    }

    @ViewBuilder
    private var metricChips: some View {
                    TodayMetricChip(
                        label: "LAST DRINK",
                        value: latestEvent.map(CaffeineFormatter.time(for:)) ?? "—",
                        tint: CafadePalette.accentText
                    )
                    TodayMetricChip(
                        label: "SLEEP TARGET",
                        value: userSettings?.bedtimeDate.map(CaffeineFormatter.time) ?? "—",
                        tint: CafadePalette.lavender
                    )
    }

    private func estimateLabel(_ estimate: CaffeineEstimate, color: Color, usesSemanticFont: Bool) -> some View {
        VStack(spacing: 4) {
            if usesSemanticFont {
                ViewThatFits(in: .horizontal) {
                    estimateValueRow(estimate, color: color, usesSemanticFont: true)
                    VStack(spacing: 2) {
                        estimateValueText(estimate, color: color, usesSemanticFont: true)
                        estimateUnitText(color: color, usesSemanticFont: true)
                    }
                }
            } else {
                estimateValueRow(estimate, color: color, usesSemanticFont: false)
            }
            Text(estimate.maxMg < 1 ? "waiting for your first log" : "fading slowly  ↘")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color.opacity(0.88))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated caffeine remaining")
        .accessibilityValue(estimate.displayText)
    }

    private func estimateValueRow(
        _ estimate: CaffeineEstimate,
        color: Color,
        usesSemanticFont: Bool
    ) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 7) {
            estimateValueText(estimate, color: color, usesSemanticFont: usesSemanticFont)
            estimateUnitText(color: color, usesSemanticFont: usesSemanticFont)
        }
        .frame(maxWidth: .infinity)
    }

    private func estimateValueText(
        _ estimate: CaffeineEstimate,
        color: Color,
        usesSemanticFont: Bool
    ) -> some View {
        Text(estimate.shortDisplayText)
            .font(
                usesSemanticFont
                    ? .system(.largeTitle, design: .serif).weight(.regular)
                    : .system(size: estimate.shortDisplayText.count > 8 ? 40 : 50, weight: .regular, design: .serif)
            )
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(usesSemanticFont ? nil : 1)
            .minimumScaleFactor(usesSemanticFont ? 1 : 0.62)
    }

    private func estimateUnitText(color: Color, usesSemanticFont: Bool) -> some View {
        Text("mg")
            .font(usesSemanticFont ? .headline : .system(size: 19, weight: .medium, design: .serif))
            .foregroundStyle(color.opacity(0.9))
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
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        targetIcon
                        targetCopy(target: target, current: current, crossing: crossing)
                        Spacer()
                        targetValue(target)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            targetIcon
                            Spacer()
                            targetValue(target)
                        }
                        targetCopy(target: target, current: current, crossing: crossing)
                    }
                }
            }
        }
    }

    private var targetIcon: some View {
        Image(systemName: "target")
            .font(.title2)
            .foregroundStyle(CafadePalette.mint)
    }

    @ViewBuilder
    private func targetCopy(target: Int, current: Double, crossing: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Personal target")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CafadePalette.paper)
            if current <= Double(target) {
                Text("Below your personal target now")
            } else if let crossing {
                Text("Below your personal target by \(CaffeineFormatter.time(crossing))")
            } else {
                Text("Your estimate stays above \(target) mg today")
            }
        }
        .font(.caption)
        .foregroundStyle(CafadePalette.mist)
    }

    private func targetValue(_ target: Int) -> some View {
        Text("\(target) mg")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(CafadePalette.mint)
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
                    ForEach(events.prefix(5)) { event in
                        RecentEventRow(event: event) {
                            Task { await repeatEvent(event) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dailyGuidanceCard: some View {
        if todayLoggedMg > CaffeineCalculator.gentleNudgeThresholdMg {
            CafadeGlassCard(tint: CafadePalette.coral.opacity(0.06)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf")
                            .font(.title3)
                            .foregroundStyle(CafadePalette.coral)
                            .accessibilityHidden(true)
                        Text("A gentle note")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CafadePalette.paper)
                        Spacer()
                        Text("TODAY")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(CafadePalette.coral)
                    }

                    Text("You’ve logged \(todayLoggedMg) mg today. You may want to take it a little easier from here.")
                        .font(.subheadline)
                        .foregroundStyle(CafadePalette.paper)

                    Text("For most healthy adults, \(CaffeineCalculator.generalDailyReferenceMg) mg/day is a commonly cited general reference—not a personal limit.")
                        .font(.caption)
                        .foregroundStyle(CafadePalette.mist)

                    Link(destination: CaffeineCalculator.dailyReferenceURL) {
                        HStack(spacing: 6) {
                            Text("Read the FDA guidance")
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.bold))
                                .accessibilityHidden(true)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CafadePalette.sky)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("today.caffeineGuidance")
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

    private var todayLoggedMg: Int {
        CaffeineCalculator.loggedTotalMg(on: now, events: events)
    }

    private var latestEvent: IntakeEvent? {
        events.first
    }

    private var shareSnapshot: CafadeShareSnapshot {
        return CafadeShareSnapshot(
            date: now,
            estimate: currentEstimate,
            events: events,
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

    private func repeatEvent(_ event: IntakeEvent) async {
        let value = CaffeineCatalog.value(for: event)
        do {
            let settings = try (userSettings ?? AppServices.ensureSettings(in: modelContext))
            let outcome = try await services.log(
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
            onLogged(outcome)
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }

    private func maybeShowHealthPrompt() async {
        guard isActive, !hasShownHealthPrompt, !events.isEmpty else { return }
        guard services.healthKit.isAvailable else { return }
        try? await Task.sleep(for: .milliseconds(550))
        guard !hasShownHealthPrompt else { return }
        hasShownHealthPrompt = true
        showingHealthPrompt = true
    }

    private func connectHealthKit() async {
        do {
            let settings = try (userSettings ?? AppServices.ensureSettings(in: modelContext))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        eventText
                        Spacer(minLength: 8)
                        eventValue
                    }
                    repeatButton
                }
            } else {
                HStack(spacing: 14) {
                    eventText
                    Spacer()
                    eventValue
                    repeatButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CafadePalette.line, lineWidth: 1)
        }
    }

    private var eventText: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(CaffeineCatalog.displayName(for: event))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                Text("\(CaffeineFormatter.date(for: event)) · \(CaffeineFormatter.time(for: event))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(CafadePalette.mist)
            }
    }

    private var eventValue: some View {
            Text(CaffeineCatalog.value(for: event).displayText)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(CafadePalette.accentText)
    }

    private var repeatButton: some View {
            Button("Repeat", action: repeatAction)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CafadePalette.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(CafadePalette.mint.opacity(0.12), in: Capsule())
                .accessibilityLabel("Repeat \(CaffeineCatalog.displayName(for: event)) now")
    }
}
