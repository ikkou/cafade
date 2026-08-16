import SwiftData
import SwiftUI

enum LogDestination: Hashable {
    case catalog(CatalogDrink)
    case custom(CustomDrinkDraft)
}

struct CustomDrinkDraft: Hashable {
    var name: String
    var caffeineMg: Int
    var servingNote: String
    var consumedAt: Date
}

struct LogCaffeineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query private var settings: [UserSettings]
    @State private var searchText = ""
    @State private var recentEvents: [IntakeEvent] = []
    @State private var isLogging = false
    @State private var errorMessage: String?

    let onLogged: (IntakeMutationOutcome) -> Void

    init(onLogged: @escaping (IntakeMutationOutcome) -> Void = { _ in }) {
        self.onLogged = onLogged
    }

    private var results: [CatalogDrink] {
        CaffeineCatalog.search(searchText, marketCode: settings.first?.marketCode ?? "US")
    }

    private var unitSystem: UnitSystem {
        settings.first?.unitSystem ?? .usCustomary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intro

                        if searchText.isEmpty {
                            catalogSection(
                                title: "Suggested",
                                items: CaffeineCatalog.suggested(marketCode: settings.first?.marketCode ?? "US"),
                                directLog: true
                            )
                            recentSection
                        } else {
                            catalogSection(title: "Results", items: results, directLog: false)
                        }

                        NavigationLink(value: LogDestination.custom(.init(
                            name: searchText,
                            caffeineMg: 0,
                            servingNote: "",
                            consumedAt: .now
                        ))) {
                            HStack(spacing: 13) {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.title3)
                                    .foregroundStyle(CafadePalette.accentText)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Custom drink")
                                        .font(.headline)
                                        .foregroundStyle(CafadePalette.paper)
                                    Text("Enter the caffeine amount from a label or medicine facts panel.")
                                        .font(.caption)
                                        .foregroundStyle(CafadePalette.mist)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(CafadePalette.mist)
                            }
                            .padding(16)
                            .background(CafadePalette.paper.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
                        }
                        .accessibilityIdentifier("log.customDrink")
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Log caffeine")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Starbucks, Red Bull, coffee...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(for: LogDestination.self) { destination in
                switch destination {
                case .catalog(let drink):
                    DrinkDetailView(drink: drink, onLogged: completeLogging)
                case .custom(let draft):
                    CustomDrinkEditorView(draft: draft, onLogged: completeLogging)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isLogging)
        .task {
            loadRecentEvents()
        }
        .alert(
            "Cafade",
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

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A small log is enough.")
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("Tap a suggestion or recent drink to log it now. Search when you want to adjust size or time.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    @ViewBuilder
    private func catalogSection(title: String, items: [CatalogDrink], directLog: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.accentText)

            if items.isEmpty {
                Text("No matching drinks yet. Add it as a custom drink below.")
                    .font(.subheadline)
                    .foregroundStyle(CafadePalette.mist)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 9) {
                    ForEach(items) { item in
                        if directLog {
                            Button {
                                Task { await logCatalogItem(item) }
                            } label: {
                                CatalogDrinkRow(item: item, unitSystem: unitSystem, showsDisclosure: false)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLogging)
                        } else {
                            NavigationLink(value: LogDestination.catalog(item)) {
                                CatalogDrinkRow(item: item, unitSystem: unitSystem, showsDisclosure: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(CafadePalette.accentText)
                LazyVStack(spacing: 9) {
                    ForEach(recentEvents) { event in
                        Button {
                            Task { await logRecentEvent(event) }
                        } label: {
                            RecentDrinkRow(event: event)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLogging)
                    }
                }
            }
        }
    }

    private func logCatalogItem(_ item: CatalogDrink) async {
        guard !isLogging else { return }
        isLogging = true
        defer { isLogging = false }
        do {
            let currentSettings = try (settings.first ?? AppServices.ensureSettings(in: modelContext))
            let outcome = try await services.log(
                value: item.value,
                catalogItemID: item.id,
                multiplier: 1,
                consumedAt: .now,
                servingNote: item.servingTitle(for: unitSystem),
                sourceKind: .catalog,
                context: modelContext,
                settings: currentSettings
            )
            completeLogging(outcome)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logRecentEvent(_ event: IntakeEvent) async {
        guard !isLogging else { return }
        isLogging = true
        defer { isLogging = false }
        do {
            let currentSettings = try (settings.first ?? AppServices.ensureSettings(in: modelContext))
            let outcome = try await services.log(
                value: CaffeineCatalog.value(for: event),
                catalogItemID: event.catalogItemID,
                customName: event.customName,
                multiplier: 1,
                consumedAt: .now,
                servingNote: event.servingNote,
                sourceKind: event.sourceKind,
                context: modelContext,
                settings: currentSettings
            )
            completeLogging(outcome)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeLogging(_ outcome: IntakeMutationOutcome) {
        onLogged(outcome)
        dismiss()
    }

    private func loadRecentEvents() {
        var descriptor = FetchDescriptor<IntakeEvent>(
            sortBy: [SortDescriptor(\IntakeEvent.consumedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        do {
            recentEvents = try modelContext.fetch(descriptor)
        } catch {
            recentEvents = []
            errorMessage = "Recent drinks could not be loaded. You can still search the catalog or add a custom drink."
        }
    }

}

private struct CatalogDrinkRow: View {
    let item: CatalogDrink
    let unitSystem: UnitSystem
    let showsDisclosure: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        drinkIcon
                        drinkText
                    }
                    HStack {
                        valueText
                        Spacer()
                        disclosureIcon
                    }
                }
            } else {
                HStack(spacing: 14) {
                    drinkIcon
                    drinkText
                    Spacer()
                    valueText
                    disclosureIcon
                }
            }
        }
        .padding(15)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
    }

    private var drinkIcon: some View {
            Image(systemName: symbol)
                .font(.title3)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.13), in: Circle())
    }

    private var drinkText: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                    .multilineTextAlignment(.leading)
                Text(item.servingTitle(for: unitSystem))
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
    }

    private var valueText: some View {
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.value.displayText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(CafadePalette.accentText)
                Text(item.value.kind.label)
                    .font(.caption2)
                    .foregroundStyle(CafadePalette.mist)
            }
    }

    private var disclosureIcon: some View {
            Image(systemName: showsDisclosure ? "chevron.right" : "plus.circle")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(showsDisclosure ? CafadePalette.mist : CafadePalette.saffron)
    }

    private var symbol: String {
        switch item.variant {
        case "energy drink": "bolt.fill"
        case "soda": "bubbles.and.sparkles"
        case "iced": "snowflake"
        default: "cup.and.saucer.fill"
        }
    }

    private var accent: Color {
        switch item.variant {
        case "energy drink": CafadePalette.coral
        case "soda": CafadePalette.sky
        case "iced": CafadePalette.mint
        default: CafadePalette.saffron
        }
    }
}

private struct RecentDrinkRow: View {
    let event: IntakeEvent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    recentText
                    HStack {
                        recentValue
                        Spacer()
                        repeatIcon
                    }
                }
            } else {
                HStack {
                    recentText
                    Spacer()
                    recentValue
                    repeatIcon
                }
            }
        }
        .padding(15)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Logs this drink now")
    }

    private var recentText: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(CaffeineCatalog.displayName(for: event))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                Text("Last logged \(CaffeineFormatter.date(for: event)) · \(CaffeineFormatter.time(for: event))")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
    }

    private var recentValue: some View {
            Text(CaffeineCatalog.value(for: event).displayText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(CafadePalette.accentText)
    }

    private var repeatIcon: some View {
            Image(systemName: "arrow.clockwise.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(CafadePalette.accentText)
    }
}
