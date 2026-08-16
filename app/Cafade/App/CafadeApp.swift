import SwiftUI
import SwiftData

@main
@MainActor
struct CafadeApp: App {
    @State private var services = AppServices()
    @StateObject private var entitlements = EntitlementService()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(services)
                .environmentObject(entitlements)
                .environment(\.locale, CaffeineFormatter.appLocale)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [IntakeEvent.self, UserSettings.self])
    }
}

enum AppTab: Hashable {
    case today
    case history
    case settings
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var entitlements: EntitlementService
    @Query(sort: \IntakeEvent.consumedAt, order: .reverse) private var widgetEvents: [IntakeEvent]
    @Query private var widgetSettings: [UserSettings]
    @State private var selectedTab: AppTab = {
        #if DEBUG
        ScreenshotFixture.initialTab
        #else
        .today
        #endif
    }()
    @State private var isLogSheetPresented = {
        #if DEBUG
        ScreenshotFixture.initiallyShowsLog
        #else
        false
        #endif
    }()
    @State private var logNotice: LogNotice?
    @State private var noticeTask: Task<Void, Never>?
    @State private var serviceMessage: String?
    @State private var isImportingWidgetEvents = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                isActive: selectedTab == .today && !isLogSheetPresented && logNotice == nil,
                openSettings: { selectedTab = .settings },
                openLog: { isLogSheetPresented = true },
                onLogged: presentLogOutcome
            )
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        .tint(CafadePalette.accentText)
        .toolbarBackground(.hidden, for: .tabBar)
        .background(CafadePalette.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == .today,
               logNotice != nil || !dynamicTypeSize.isAccessibilitySize {
                CafadeLogOverlay(notice: logNotice) {
                    isLogSheetPresented = true
                } undo: {
                    undoLastLog()
                }
            }
        }
        .accessibilityHidden(isLogSheetPresented)
        .sheet(isPresented: $isLogSheetPresented) {
            LogCaffeineSheet(onLogged: presentLogOutcome)
                .environment(services)
        }
        .alert(
            "Cafade",
            isPresented: Binding(
                get: { serviceMessage != nil },
                set: { if !$0 { serviceMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { serviceMessage = nil }
        } message: {
            Text(serviceMessage ?? "")
        }
        .task {
            do {
                #if DEBUG
                try ScreenshotFixture.installIfRequested(in: modelContext)
                #endif
                let settings = try AppServices.ensureSettings(in: modelContext)
                await importPendingWidgetEvents(settings: settings)
                publishWidgetSnapshot()
            } catch {
                serviceMessage = error.localizedDescription
            }
            await entitlements.refresh()
        }
        .task(id: widgetSyncFingerprint) {
            publishWidgetSnapshot()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                if let settings = try? AppServices.ensureSettings(in: modelContext) {
                    await importPendingWidgetEvents(settings: settings)
                    publishWidgetSnapshot()
                }
                _ = await entitlements.refreshCustomerInfo()
            }
        }
        .onDisappear {
            noticeTask?.cancel()
        }
    }

    private func presentLogOutcome(_ outcome: IntakeMutationOutcome) {
        guard let event = outcome.event else { return }
        noticeTask?.cancel()
        logNotice = LogNotice(event: event)
        if let warning = outcome.healthWarning {
            serviceMessage = warning
        }
        let noticeDuration: Duration = dynamicTypeSize.isAccessibilitySize ? .seconds(20) : .seconds(10)
        noticeTask = Task {
            try? await Task.sleep(for: noticeDuration)
            guard !Task.isCancelled else { return }
            logNotice = nil
        }
    }

    private func undoLastLog() {
        guard let notice = logNotice else { return }
        noticeTask?.cancel()
        logNotice = nil
        Task {
            do {
                let settings = try AppServices.ensureSettings(in: modelContext)
                let outcome = try await services.delete(
                    event: notice.event,
                    context: modelContext,
                    settings: settings
                )
                if let warning = outcome.healthWarning {
                    serviceMessage = warning
                }
            } catch {
                serviceMessage = "Undo could not be completed. \(error.localizedDescription)"
            }
        }
    }

    private var widgetSyncFingerprint: String {
        let eventFingerprint = widgetEvents.map {
            "\($0.id.uuidString):\($0.updatedAt.timeIntervalSinceReferenceDate)"
        }
        .joined(separator: "|")
        let settingsFingerprint = widgetSettings.map { "\($0.id):\($0.halfLifeHours)" }.joined(separator: "|")
        return eventFingerprint + "#" + settingsFingerprint
    }

    private func publishWidgetSnapshot() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-14 * 24 * 3_600)
        let sharedEvents = widgetEvents
            .filter { $0.consumedAt <= now && $0.consumedAt >= cutoff }
            .map(widgetEvent(from:))

        var quickDrinks: [CafadeWidgetQuickDrink] = []
        for event in sharedEvents {
            let drink = event.quickDrink
            guard !quickDrinks.contains(where: { $0.id == drink.id }) else { continue }
            quickDrinks.append(drink)
            if quickDrinks.count == 3 { break }
        }

        let snapshot = CafadeWidgetSnapshot(
            events: sharedEvents,
            quickDrinks: quickDrinks,
            halfLifeHours: widgetSettings.first?.halfLifeHours ?? 4,
            updatedAt: now
        )
        CafadeWidgetStore.saveSnapshot(snapshot)
    }

    private func widgetEvent(from event: IntakeEvent) -> CafadeWidgetEvent {
        let canRepeatAsCatalogItem = event.sourceKind == .catalog
            && event.catalogItemID.flatMap(CaffeineCatalog.item(id:)) != nil
        return CafadeWidgetEvent(
            id: event.id,
            name: CaffeineCatalog.displayName(for: event),
            catalogItemID: canRepeatAsCatalogItem ? event.catalogItemID : nil,
            caffeineMg: event.caffeineMg,
            minMg: event.minMg,
            maxMg: event.maxMg,
            valueKindRaw: event.valueKind.rawValue,
            sourceKindRaw: canRepeatAsCatalogItem ? IntakeSourceKind.catalog.rawValue : IntakeSourceKind.custom.rawValue,
            consumedAt: event.consumedAt
        )
    }

    private func importPendingWidgetEvents(settings: UserSettings) async {
        guard !isImportingWidgetEvents else { return }
        isImportingWidgetEvents = true
        defer { isImportingWidgetEvents = false }

        let pendingEvents = CafadeWidgetStore.pendingEvents()
        guard !pendingEvents.isEmpty else { return }

        do {
            let storedEvents = try modelContext.fetch(FetchDescriptor<IntakeEvent>())
            var knownIDs = Set(storedEvents.map(\.id))
            var importedEvents: [IntakeEvent] = []
            let now = Date()

            for pending in pendingEvents where !knownIDs.contains(pending.id) {
                let name = pending.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name.count <= CaffeineCalculator.customNameMaximumLength else { continue }

                let valueKind = CatalogValueKind(rawValue: pending.valueKindRaw)
                    ?? ((pending.minMg != nil && pending.maxMg != nil) ? .range : .approximate)
                let value = CaffeineValue(
                    kind: valueKind,
                    typicalMg: pending.caffeineMg,
                    minMg: pending.minMg,
                    maxMg: pending.maxMg
                )
                guard value.isValid(maximumMg: CaffeineCalculator.customEntryMaximumMg) else { continue }

                let catalogItemID = pending.catalogItemID.flatMap { id in
                    CaffeineCatalog.item(id: id) == nil ? nil : id
                }
                let sourceKind: IntakeSourceKind = catalogItemID == nil ? .custom : .catalog
                let consumedAt = min(pending.consumedAt, now)
                let event = IntakeEvent(
                    id: pending.id,
                    catalogItemID: catalogItemID,
                    customName: sourceKind == .custom ? name : nil,
                    caffeineMg: value.typicalMg,
                    minMg: value.minMg,
                    maxMg: value.maxMg,
                    valueKind: value.kind,
                    consumedAt: consumedAt,
                    consumedTimeZoneIdentifier: TimeZone.current.identifier,
                    sourceKind: sourceKind,
                    createdAt: consumedAt,
                    updatedAt: consumedAt
                )
                modelContext.insert(event)
                importedEvents.append(event)
                knownIDs.insert(event.id)
            }

            if !importedEvents.isEmpty {
                try modelContext.save()
            }
            CafadeWidgetStore.acknowledgePendingEvents(ids: Set(pendingEvents.map(\.id)))

            guard settings.healthKitWriteEnabled, !importedEvents.isEmpty else { return }
            var healthSyncFailureCount = 0
            for event in importedEvents {
                do {
                    try await services.healthKit.replace(event: event)
                } catch {
                    healthSyncFailureCount += 1
                }
            }
            if healthSyncFailureCount > 0 {
                serviceMessage = "Widget logs were saved in Cafade, but Apple Health could not sync \(healthSyncFailureCount) entr\(healthSyncFailureCount == 1 ? "y" : "ies"). Reconnect Apple Health in Settings to retry."
            }
        } catch {
            modelContext.rollback()
            serviceMessage = "Cafade could not import a widget log. It remains queued and will be retried."
        }
    }
}

private struct LogNotice: Identifiable {
    let id = UUID()
    let event: IntakeEvent

    var title: String {
        "Logged \(CaffeineCatalog.displayName(for: event))"
    }
}

private struct CafadeLogOverlay: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let notice: LogNotice?
    let log: () -> Void
    let undo: () -> Void

    var body: some View {
        Group {
            if let notice {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 9) {
                                noticeIcon
                                noticeTitle(notice)
                            }
                            Button("Undo", action: undo)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CafadePalette.accentText)
                        }
                    } else {
                        HStack(spacing: 10) {
                            noticeIcon
                            noticeTitle(notice)
                            Spacer(minLength: 2)
                            Button("Undo", action: undo)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CafadePalette.accentText)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .frame(maxWidth: 330)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 20 : 28, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 20 : 28, style: .continuous)
                        .stroke(CafadePalette.line, lineWidth: 1)
                }
                .shadow(color: CafadePalette.ink.opacity(0.14), radius: 14, y: 6)
                .accessibilityElement(children: .contain)
            } else {
                Button(action: log) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.glass)
                .tint(CafadePalette.saffron)
                .accessibilityLabel("Log caffeine")
                .accessibilityIdentifier("today.logCaffeine")
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 76)
        .animation(.snappy(duration: 0.3), value: notice?.id)
        .sensoryFeedback(.success, trigger: notice?.id)
    }

    private var noticeIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(CafadePalette.mint)
    }

    private func noticeTitle(_ notice: LogNotice) -> some View {
        Text(notice.title)
            .font(.subheadline.weight(.medium))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
    }
}
