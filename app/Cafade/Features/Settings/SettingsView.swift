import SwiftData
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum SettingsDestination: Hashable {
    case estimateInfo
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @EnvironmentObject private var entitlements: EntitlementService
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Query private var settings: [UserSettings]

    @State private var showingTargetEditor = false
    @State private var showingPaywall = false
    @State private var showingDeleteConfirmation = false
    @State private var message: String?
    @State private var isWorking = false
    @State private var isExporting = false
    @State private var exportDocument = CafadeExportDocument()
    @State private var navigationPath: [SettingsDestination] = {
        #if DEBUG
        ScreenshotFixture.initiallyShowsModelExplanation ? [.estimateInfo] : []
        #else
        []
        #endif
    }()

    private var activeSettings: UserSettings? { settings.first }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        modelSection
                        dailySection
                        healthSection
                        appearanceSection
                        subscriptionSection
                        aboutSection
                        dataSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityHidden(showingTargetEditor || showingPaywall || isExporting)
            .sheet(isPresented: $showingTargetEditor) {
                if let activeSettings {
                    DailyTargetSheet(settings: activeSettings)
                } else {
                    ContentUnavailableView("Settings unavailable", systemImage: "exclamationmark.triangle")
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(entitlements)
            }
            .alert(
                "Cafade",
                isPresented: Binding(
                    get: { message != nil },
                    set: { if !$0 { message = nil } }
                )
            ) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog("Delete all Cafade data?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    Task { await deleteAllData() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes your Cafade log, settings, and Cafade samples from Apple Health.")
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "cafade-export"
            ) { result in
                if case .failure(let error) = result {
                    message = "The export could not be saved. \(error.localizedDescription)"
                }
            }
            .task {
                do {
                    _ = try AppServices.ensureSettings(in: modelContext)
                } catch {
                    message = error.localizedDescription
                }
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .estimateInfo:
                    EstimateInfoView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("YOUR SETUP")
                .font(.caption.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(CafadePalette.accentText)
            Text("Settings")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("Tune the estimate to the way you actually use Cafade.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var modelSection: some View {
        settingsGroup(title: "CAFFEINE MODEL") {
            VStack(spacing: 0) {
                SettingsRow(title: "Half-life", detail: "How quickly the estimate fades", symbol: "waveform.path") {
                    Menu {
                        ForEach(UserSettings.supportedHalfLifeHours, id: \.self) { hours in
                            Button {
                                activeSettings?.halfLifeHours = hours
                                saveSettings()
                            } label: {
                                if activeSettings?.halfLifeHours == hours {
                                    Label("\(hours) hours", systemImage: "checkmark")
                                } else {
                                    Text("\(hours) hours")
                                }
                            }
                        }
                    } label: {
                        Text("\(activeSettings?.halfLifeHours ?? 4) hours")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(CafadePalette.accentText)
                    }
                    .accessibilityLabel("Caffeine half-life")
                    .accessibilityValue("\(activeSettings?.halfLifeHours ?? 4) hours")
                }
                Divider().overlay(CafadePalette.line)
                NavigationLink(value: SettingsDestination.estimateInfo) {
                    SettingsRowLabel(title: "How the model works", detail: "Read the simple half-life explanation", symbol: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.modelExplanation")
            }
        }
    }

    private var dailySection: some View {
        settingsGroup(title: "YOUR DAY") {
            VStack(spacing: 0) {
                Button { showingTargetEditor = true } label: {
                    SettingsRowLabel(
                        title: "Personal target",
                        detail: activeSettings?.dailyTargetMg.map { "\($0) mg" } ?? "Not set",
                        symbol: "target"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(CafadePalette.line)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 13) {
                        bedtimeLabel
                        Spacer()
                        bedtimePicker
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        bedtimeLabel
                        bedtimePicker
                    }
                }
                .padding(.vertical, 14)
            }
        }
    }

    private var healthSection: some View {
        settingsGroup(title: "HEALTH") {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 13) {
                    Image(systemName: "heart.text.square")
                        .font(.title3)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(CafadePalette.coral)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Health")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CafadePalette.paper)
                        Text(healthStatusText)
                            .font(.caption)
                            .foregroundStyle(CafadePalette.mist)
                    }
                    Spacer()
                    if isHealthSyncEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CafadePalette.mint)
                    } else if services.healthKit.isWriteDenied {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(CafadePalette.coral)
                    } else if services.healthKit.isWriteAuthorized {
                        Image(systemName: "pause.circle")
                            .foregroundStyle(CafadePalette.mist)
                    }
                }
                Text("Cafade writes only the entries you choose to save. It does not read sleep data in this release. Pausing keeps existing Health samples in place. If you previously denied access, re-enable Dietary Caffeine in the Health app before reconnecting.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                Button {
                    if services.healthKit.isWriteDenied {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } else {
                        Task { await connectHealthKit() }
                    }
                } label: {
                    Text(healthActionTitle)
                }
                .buttonStyle(CafadeSecondaryButtonStyle())
                .disabled(isWorking)

                if isHealthSyncEnabled {
                    Button("Stop saving new entries") {
                        pauseHealthKitWrites()
                    }
                    .buttonStyle(CafadeSecondaryButtonStyle())
                    .disabled(isWorking)
                }

                if services.hasPendingHealthCleanup {
                    Divider().overlay(CafadePalette.line)
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Apple Health cleanup is pending for one or more deleted Cafade entries.")
                            .font(.caption)
                            .foregroundStyle(CafadePalette.mist)
                        Button("Retry Health cleanup") {
                            Task { await retryHealthCleanup() }
                        }
                        .buttonStyle(CafadeSecondaryButtonStyle())
                        .disabled(isWorking)
                    }
                }
            }
        }
    }

    private var appearanceSection: some View {
        settingsGroup(title: "APPEARANCE") {
            VStack(spacing: 0) {
                SettingsRow(title: "Units", detail: "Volume shown throughout the app", symbol: "ruler") {
                    Menu {
                        ForEach(UnitSystem.allCases) { unit in
                            Button {
                                unitBinding.wrappedValue = unit
                            } label: {
                                if unitBinding.wrappedValue == unit {
                                    Label(unit.title, systemImage: "checkmark")
                                } else {
                                    Text(unit.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(activeSettings?.unitSystem.title ?? UnitSystem.usCustomary.title)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CafadePalette.accentText)
                    }
                    .accessibilityLabel("Units")
                    .accessibilityValue(activeSettings?.unitSystem.title ?? UnitSystem.usCustomary.title)
                }
                Divider().overlay(CafadePalette.line)
                SettingsRow(
                    title: "Reduce motion",
                    detail: systemReduceMotion ? "On · iPhone Settings > Accessibility > Motion" : "Off · iPhone Settings > Accessibility > Motion",
                    symbol: "figure.walk.motion"
                ) {
                    Link(destination: URL(string: "https://support.apple.com/en-us/guide/iphone/reduce-screen-motion-iph0b691d3ed/ios")!) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(CafadePalette.sky)
                    }
                    .accessibilityLabel("Learn how to change Reduce Motion in iPhone Settings")
                }
            }
        }
    }

    private var subscriptionSection: some View {
        settingsGroup(title: "SUBSCRIPTION") {
            VStack(spacing: 0) {
                Button {
                    if entitlements.isPro {
                        Task { await showSubscriptionManagement() }
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    SettingsRowLabel(
                        title: "Cafade Pro",
                        detail: entitlements.isPro ? "Active · Manage subscription" : "Longer history and patterns",
                        symbol: "sparkles"
                    )
                }
                .buttonStyle(.plain)
                Divider().overlay(CafadePalette.line)
                Button {
                    Task { await entitlements.restorePurchases() }
                } label: {
                    SettingsRowLabel(title: "Restore purchases", detail: "Check your App Store subscription", symbol: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(entitlements.state.isBusy)
                if let message = entitlements.lastMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(CafadePalette.mist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
            }
        }
    }

    private var aboutSection: some View {
        settingsGroup(title: "ABOUT") {
            VStack(spacing: 0) {
                Link(destination: URL(string: "https://cafade.oneshotstar.com/support/")!) {
                    SettingsRowLabel(title: "Support", detail: "Guides and contact information", symbol: "questionmark.circle")
                }
                Divider().overlay(CafadePalette.line)
                Link(destination: URL(string: "https://cafade.oneshotstar.com/privacy/")!) {
                    SettingsRowLabel(title: "Privacy", detail: "How Cafade handles your data", symbol: "hand.raised")
                }
                Divider().overlay(CafadePalette.line)
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    SettingsRowLabel(title: "Apple Standard EULA", detail: "Terms used for Cafade subscriptions", symbol: "doc.text")
                }
            }
        }
    }

    private var dataSection: some View {
        settingsGroup(title: "YOUR DATA") {
            VStack(spacing: 0) {
                Button {
                    prepareExport()
                } label: {
                    SettingsRowLabel(title: "Export data", detail: "Save a readable JSON copy", symbol: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                Divider().overlay(CafadePalette.line)
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    SettingsRowLabel(title: "Delete all data", detail: "Remove the local log and Cafade Health samples", symbol: "trash")
                        .foregroundStyle(CafadePalette.coral)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.accentText)
            CafadeGlassCard { content() }
        }
    }

    private var unitBinding: Binding<UnitSystem> {
        Binding(
            get: { activeSettings?.unitSystem ?? .usCustomary },
            set: {
                activeSettings?.unitSystem = $0
                saveSettings()
            }
        )
    }

    private var healthStatusText: String {
        if isHealthSyncEnabled {
            return "Connected for Dietary Caffeine"
        }
        if services.healthKit.isWriteDenied {
            return "Access is off in Apple Health"
        }
        if services.healthKit.isWriteAuthorized {
            return "Permission allowed · saving is paused"
        }
        if activeSettings?.healthKitWriteEnabled == true {
            return "Reconnect to confirm Apple Health access"
        }
        return "Not connected"
    }

    private var isHealthSyncEnabled: Bool {
        services.healthKit.isWriteAuthorized && activeSettings?.healthKitWriteEnabled == true
    }

    private var healthActionTitle: String {
        if isHealthSyncEnabled { return "Sync saved entries" }
        if services.healthKit.isWriteDenied { return "Open iPhone Settings" }
        if services.healthKit.isWriteAuthorized { return "Resume Apple Health" }
        return "Connect Apple Health"
    }

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: {
                activeSettings?.bedtimeDate ?? Calendar.current.date(from: DateComponents(hour: 23, minute: 0)) ?? .now
            },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                if let hour = components.hour, let minute = components.minute {
                    activeSettings?.typicalBedtimeMinutes = hour * 60 + minute
                    saveSettings()
                }
            }
        )
    }

    private var bedtimeLabel: some View {
        HStack(spacing: 13) {
            Image(systemName: "moon.stars")
                .font(.body)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.lavender)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text("Typical bedtime")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CafadePalette.paper)
                Text(activeSettings?.bedtimeDate.map(CaffeineFormatter.time) ?? "Not set")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }

    private var bedtimePicker: some View {
        DatePicker("Typical bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .tint(CafadePalette.accentText)
    }

    private func saveSettings() {
        do {
            try AppServices.saveSettings(in: modelContext)
        } catch {
            message = error.localizedDescription
        }
    }

    private func connectHealthKit() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let current = try (activeSettings ?? AppServices.ensureSettings(in: modelContext))
            let events = try fetchAllEvents()
            try await services.requestHealthKitAndSync(events: events, settings: current, context: modelContext)
            message = "Apple Health is connected. Your saved Cafade entries have been synced."
        } catch {
            message = error.localizedDescription
        }
    }

    private func pauseHealthKitWrites() {
        guard let activeSettings else { return }
        activeSettings.healthKitWriteEnabled = false
        do {
            try AppServices.saveSettings(in: modelContext)
            message = "New entries will stay in Cafade only. Existing Apple Health samples were not removed."
        } catch {
            message = error.localizedDescription
        }
    }

    private func retryHealthCleanup() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if let warning = await services.retryPendingHealthCleanup() {
            message = warning
        } else {
            message = "Apple Health cleanup is complete."
        }
    }

    private func deleteAllData() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let current = try (activeSettings ?? AppServices.ensureSettings(in: modelContext))
            let events = try fetchAllEvents()
            let outcome = try await services.deleteAll(
                events: events,
                context: modelContext,
                settings: current
            )
            message = outcome.healthWarning ?? "All local Cafade data was deleted."
        } catch {
            message = error.localizedDescription
        }
    }

    private func prepareExport() {
        do {
            let current = try (activeSettings ?? AppServices.ensureSettings(in: modelContext))
            exportDocument = try CafadeExportDocument(events: fetchAllEvents(), settings: current)
            isExporting = true
        } catch {
            message = "Cafade could not prepare the export. \(error.localizedDescription)"
        }
    }

    private func fetchAllEvents() throws -> [IntakeEvent] {
        let descriptor = FetchDescriptor<IntakeEvent>(
            sortBy: [SortDescriptor(\IntakeEvent.consumedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func showSubscriptionManagement() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            message = "Subscription management is not available right now. Please try again."
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            _ = await entitlements.refreshCustomerInfo()
        } catch {
            message = "The App Store subscription screen could not be opened. \(error.localizedDescription)"
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let detail: String
    let symbol: String
    let accessory: () -> Accessory
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, detail: String, symbol: String, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.accessory = accessory
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    rowLabel
                    accessory()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 13) {
                    rowLabel
                    Spacer()
                    accessory()
                }
            }
        }
        .padding(.vertical, 14)
    }

    private var rowLabel: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.body)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.mint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CafadePalette.paper)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.body)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.mint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CafadePalette.paper)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.mist)
                .padding(.top, 3)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

struct DailyTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let settings: UserSettings
    @State private var targetText: String
    @State private var errorMessage: String?
    @FocusState private var isTargetFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(settings: UserSettings) {
        self.settings = settings
        _targetText = State(initialValue: settings.dailyTargetMg.map(String.init) ?? "")
    }

    private var targetMg: Int? {
        guard let value = Int(targetText),
              (CaffeineCalculator.customEntryMinimumMg...CaffeineCalculator.customEntryMaximumMg).contains(value)
        else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("A personal comparison point, not a safety limit.")
                            .font(.subheadline)
                            .foregroundStyle(CafadePalette.mist)
                        HStack {
                            TextField("1–1,000", text: $targetText)
                                .keyboardType(.numberPad)
                                .font(.title2.monospacedDigit())
                                .focused($isTargetFocused)
                            Text("mg")
                                .foregroundStyle(CafadePalette.accentText)
                        }
                        .padding(16)
                        .background(CafadePalette.paper.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button("Save target") {
                            saveTarget()
                        }
                        .buttonStyle(CafadePrimaryButtonStyle())
                        .disabled(targetMg == nil)
                        .opacity(targetMg == nil ? 0.55 : 1)
                        Button("Clear target") {
                            clearTarget()
                        }
                        .buttonStyle(CafadeSecondaryButtonStyle())
                    }
                    .padding(22)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Personal target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(250))
                isTargetFocused = true
            }
            .alert(
                "Could not save target",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }

    private func saveTarget() {
        guard let targetMg else { return }
        settings.dailyTargetMg = targetMg
        persistAndDismiss()
    }

    private func clearTarget() {
        settings.dailyTargetMg = nil
        persistAndDismiss()
    }

    private func persistAndDismiss() {
        do {
            try AppServices.saveSettings(in: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CafadeExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init() {
        data = Data("{}".utf8)
    }

    init(events: [IntakeEvent], settings: UserSettings) throws {
        let payload = CafadeExportPayload(
            exportedAt: .now,
            settings: .init(settings: settings),
            events: events.map(CafadeExportEvent.init(event:))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(payload)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct CafadeExportPayload: Codable {
    let exportedAt: Date
    let settings: CafadeExportSettings
    let events: [CafadeExportEvent]
}

private struct CafadeExportSettings: Codable {
    let marketCode: String
    let languageCode: String
    let unitSystem: String
    let halfLifeHours: Int
    let dailyTargetMg: Int?
    let typicalBedtimeMinutes: Int?

    init(settings: UserSettings) {
        marketCode = settings.marketCode
        languageCode = settings.languageCode
        unitSystem = settings.unitSystem.rawValue
        halfLifeHours = settings.halfLifeHours
        dailyTargetMg = settings.dailyTargetMg
        typicalBedtimeMinutes = settings.typicalBedtimeMinutes
    }
}

private struct CafadeExportEvent: Codable {
    let id: UUID
    let catalogItemID: String?
    let customName: String?
    let caffeineMg: Int
    let minMg: Int?
    let maxMg: Int?
    let quantityMultiplier: Double
    let consumedAt: Date
    let servingNote: String?
    let sourceKind: String
    let valueKind: String
    let consumedTimeZoneIdentifier: String?

    init(event: IntakeEvent) {
        id = event.id
        catalogItemID = event.catalogItemID
        customName = event.customName
        caffeineMg = event.caffeineMg
        minMg = event.minMg
        maxMg = event.maxMg
        quantityMultiplier = event.quantityMultiplier
        consumedAt = event.consumedAt
        servingNote = event.servingNote
        sourceKind = event.sourceKindRaw
        valueKind = event.valueKind.rawValue
        consumedTimeZoneIdentifier = event.consumedTimeZoneIdentifier
    }
}
