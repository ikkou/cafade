import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @EnvironmentObject private var entitlements: EntitlementService
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Query private var settings: [UserSettings]
    @Query private var events: [IntakeEvent]

    @State private var showingTargetEditor = false
    @State private var showingPaywall = false
    @State private var showingHealthError = false
    @State private var showingDeleteConfirmation = false
    @State private var healthErrorMessage = ""
    @State private var isExporting = false
    @State private var exportDocument = CafadeExportDocument()

    private var activeSettings: UserSettings? { settings.first }

    var body: some View {
        NavigationStack {
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
            .sheet(isPresented: $showingTargetEditor) {
                DailyTargetSheet(settings: activeSettings ?? AppServices.ensureSettings(in: modelContext))
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(entitlements)
            }
            .alert("Apple Health", isPresented: $showingHealthError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(healthErrorMessage)
            }
            .confirmationDialog("Delete all Cafade data?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    let current = activeSettings ?? AppServices.ensureSettings(in: modelContext)
                    services.deleteAll(events: events, context: modelContext, settings: current)
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
            ) { _ in }
            .task {
                _ = AppServices.ensureSettings(in: modelContext)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("YOUR SETUP")
                .font(.caption.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(CafadePalette.saffron)
            Text("Settings")
                .font(.system(size: 38, weight: .medium, design: .serif))
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
                        ForEach([2, 4, 6, 8], id: \.self) { hours in
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
                            .foregroundStyle(CafadePalette.saffron)
                    }
                }
                Divider().overlay(CafadePalette.line)
                NavigationLink {
                    EstimateInfoView()
                } label: {
                    SettingsRowLabel(title: "How the model works", detail: "Read the simple half-life explanation", symbol: "questionmark.circle")
                }
                .buttonStyle(.plain)
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
                HStack(spacing: 13) {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(CafadePalette.lavender)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Typical bedtime")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(CafadePalette.paper)
                        Text(activeSettings?.bedtimeDate.map { $0.formatted(date: .omitted, time: .shortened) } ?? "Not set")
                            .font(.caption)
                            .foregroundStyle(CafadePalette.mist)
                    }
                    Spacer()
                    DatePicker("Typical bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(CafadePalette.saffron)
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
                        .foregroundStyle(CafadePalette.coral)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Health")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CafadePalette.paper)
                        Text(activeSettings?.healthKitWriteEnabled == true ? "Connected for Dietary Caffeine" : "Not connected")
                            .font(.caption)
                            .foregroundStyle(CafadePalette.mist)
                    }
                    Spacer()
                    if activeSettings?.healthKitWriteEnabled == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CafadePalette.mint)
                    }
                }
                Text("Cafade writes only the entries you choose to save. It does not read sleep data in this release.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                Button {
                    Task { await connectHealthKit() }
                } label: {
                    Text(activeSettings?.healthKitWriteEnabled == true ? "Reconnect Apple Health" : "Connect Apple Health")
                }
                .buttonStyle(CafadeSecondaryButtonStyle())
            }
        }
    }

    private var appearanceSection: some View {
        settingsGroup(title: "APPEARANCE") {
            VStack(spacing: 0) {
                HStack(spacing: 13) {
                    Image(systemName: "ruler")
                        .foregroundStyle(CafadePalette.mint)
                        .frame(width: 24)
                    Text("Units")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CafadePalette.paper)
                    Spacer()
                    Picker("Units", selection: unitBinding) {
                        ForEach(UnitSystem.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CafadePalette.saffron)
                }
                .padding(.vertical, 14)
                Divider().overlay(CafadePalette.line)
                SettingsRow(title: "Reduce motion", detail: systemReduceMotion ? "On in Accessibility" : "Off in Accessibility", symbol: "figure.walk.motion") {
                    Image(systemName: systemReduceMotion ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(systemReduceMotion ? CafadePalette.mint : CafadePalette.mist)
                }
            }
        }
    }

    private var subscriptionSection: some View {
        settingsGroup(title: "SUBSCRIPTION") {
            VStack(spacing: 0) {
                Button { showingPaywall = true } label: {
                    SettingsRowLabel(
                        title: "Cafade Pro",
                        detail: entitlements.isPro ? "Active" : "Longer history and patterns",
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
                    SettingsRowLabel(title: "Terms", detail: "Apple standard terms of use", symbol: "doc.text")
                }
            }
        }
    }

    private var dataSection: some View {
        settingsGroup(title: "YOUR DATA") {
            VStack(spacing: 0) {
                Button {
                    exportDocument = CafadeExportDocument(events: events, settings: activeSettings ?? UserSettings())
                    isExporting = true
                } label: {
                    SettingsRowLabel(title: "Export data", detail: "Save a readable JSON copy", symbol: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                Divider().overlay(CafadePalette.line)
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    SettingsRowLabel(title: "Delete all data", detail: "Remove the local log and Cafade Health samples", symbol: "trash")
                        .foregroundStyle(CafadePalette.coral)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.saffron)
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

    private func saveSettings() {
        try? modelContext.save()
    }

    private func connectHealthKit() async {
        let current = activeSettings ?? AppServices.ensureSettings(in: modelContext)
        do {
            try await services.requestHealthKitAndSync(events: events, settings: current, context: modelContext)
        } catch {
            healthErrorMessage = error.localizedDescription
            showingHealthError = true
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let detail: String
    let symbol: String
    let accessory: () -> Accessory

    init(title: String, detail: String, symbol: String, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .foregroundStyle(CafadePalette.mint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CafadePalette.paper)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
            Spacer()
            accessory()
        }
        .padding(.vertical, 14)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .foregroundStyle(CafadePalette.mint)
                .frame(width: 24)
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
                .foregroundStyle(CafadePalette.mist)
        }
        .padding(.vertical, 14)
    }
}

struct DailyTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let settings: UserSettings
    @State private var targetText: String
    @FocusState private var isTargetFocused: Bool

    init(settings: UserSettings) {
        self.settings = settings
        _targetText = State(initialValue: settings.dailyTargetMg.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                VStack(alignment: .leading, spacing: 22) {
                    Text("A personal comparison point, not a safety limit.")
                        .font(.subheadline)
                        .foregroundStyle(CafadePalette.mist)
                    HStack {
                        TextField("e.g. 200", text: $targetText)
                            .keyboardType(.numberPad)
                            .font(.title2.monospacedDigit())
                            .focused($isTargetFocused)
                        Text("mg")
                            .foregroundStyle(CafadePalette.saffron)
                    }
                    .padding(16)
                    .background(CafadePalette.paper.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Button("Save target") {
                        settings.dailyTargetMg = Int(targetText).map { min(max($0, 0), 2_000) }
                        try? modelContext.save()
                        dismiss()
                    }
                    .buttonStyle(CafadePrimaryButtonStyle())
                    Button("Clear target") {
                        settings.dailyTargetMg = nil
                        try? modelContext.save()
                        dismiss()
                    }
                    .buttonStyle(CafadeSecondaryButtonStyle())
                    Spacer()
                }
                .padding(22)
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
        }
        .presentationDetents([.medium])
    }
}

struct CafadeExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init() {
        data = Data("{}".utf8)
    }

    init(events: [IntakeEvent], settings: UserSettings) {
        let payload = CafadeExportPayload(
            exportedAt: .now,
            settings: .init(settings: settings),
            events: events.map(CafadeExportEvent.init(event:))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
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
    }
}
