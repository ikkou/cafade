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
    @Query(sort: \IntakeEvent.consumedAt, order: .reverse) private var events: [IntakeEvent]
    @Query private var settings: [UserSettings]
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var results: [CatalogDrink] {
        CaffeineCatalog.search(searchText)
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
                            catalogSection(title: "Suggested", items: CaffeineCatalog.suggested())
                            recentSection
                        } else {
                            catalogSection(title: "Results", items: results)
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
                                    .foregroundStyle(CafadePalette.saffron)
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
            .searchFocused($isSearchFocused)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(for: LogDestination.self) { destination in
                switch destination {
                case .catalog(let drink):
                    DrinkDetailView(drink: drink)
                case .custom(let draft):
                    CustomDrinkEditorView(draft: draft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            isSearchFocused = true
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A small log is enough.")
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("Choose something familiar, then adjust the size and time.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    @ViewBuilder
    private func catalogSection(title: String, items: [CatalogDrink]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.saffron)

            if items.isEmpty {
                Text("No matching drinks yet. Add it as a custom drink below.")
                    .font(.subheadline)
                    .foregroundStyle(CafadePalette.mist)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 9) {
                    ForEach(items) { item in
                        NavigationLink(value: LogDestination.catalog(item)) {
                            CatalogDrinkRow(item: item, unitSystem: unitSystem)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(CafadePalette.saffron)
                LazyVStack(spacing: 9) {
                    ForEach(Array(events.prefix(5))) { event in
                        NavigationLink(value: destination(for: event)) {
                            RecentDrinkRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func destination(for event: IntakeEvent) -> LogDestination {
        if let item = CaffeineCatalog.item(id: event.catalogItemID) {
            return .catalog(item)
        }
        return .custom(CustomDrinkDraft(
            name: event.customName ?? "Custom drink",
            caffeineMg: event.caffeineMg,
            servingNote: event.servingNote ?? "",
            consumedAt: .now
        ))
    }
}

private struct CatalogDrinkRow: View {
    let item: CatalogDrink
    let unitSystem: UnitSystem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                    .multilineTextAlignment(.leading)
                Text(item.servingTitle(for: unitSystem))
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.value.displayText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(CafadePalette.saffron)
                Text(item.value.kind.label)
                    .font(.caption2)
                    .foregroundStyle(CafadePalette.mist)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(CafadePalette.mist)
        }
        .padding(15)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(CaffeineCatalog.displayName(for: event))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                Text("Last logged \(CaffeineFormatter.time(event.consumedAt))")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
            Spacer()
            Text(CaffeineCatalog.value(for: event).displayText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(CafadePalette.saffron)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(CafadePalette.mist)
        }
        .padding(15)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CafadePalette.line, lineWidth: 1))
    }
}
