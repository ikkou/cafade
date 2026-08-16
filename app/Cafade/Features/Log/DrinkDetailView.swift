import SwiftData
import SwiftUI

struct DrinkDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query private var settings: [UserSettings]

    let drink: CatalogDrink
    let onLogged: (IntakeMutationOutcome) -> Void
    @State private var selectedItemID: String
    @State private var multiplier = 1.0
    @State private var consumedAt = Date.now
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(drink: CatalogDrink, onLogged: @escaping (IntakeMutationOutcome) -> Void = { _ in }) {
        self.drink = drink
        self.onLogged = onLogged
        _selectedItemID = State(initialValue: drink.id)
    }

    private var selectedItem: CatalogDrink {
        CaffeineCatalog.item(id: selectedItemID) ?? drink
    }

    private var variants: [CatalogDrink] {
        CaffeineCatalog.variants(
            for: drink.familyID,
            marketCode: settings.first?.marketCode ?? drink.marketCode
        )
    }

    private var unitSystem: UnitSystem {
        settings.first?.unitSystem ?? .usCustomary
    }

    var body: some View {
        ZStack {
            CafadeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    titleBlock
                    valueBlock
                    sizeBlock
                    multiplierBlock
                    timeBlock
                    sourceBlock
                    Button {
                        Task { await logNow() }
                    } label: {
                        Text("Log \(selectedItem.value.scaled(by: multiplier).displayText)")
                    }
                    .buttonStyle(CafadePrimaryButtonStyle())
                    .disabled(isSaving || !isFinalValueValid)
                    .opacity(isFinalValueValid ? 1 : 0.55)
                    .accessibilityIdentifier("drinkDetail.logNow")
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Drink detail")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .alert(
            "Could not log caffeine",
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

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedItem.brand?.uppercased() ?? "CUSTOM CATALOG")
                .font(.caption.weight(.semibold))
                .tracking(1.7)
                .foregroundStyle(CafadePalette.accentText)
            Text(selectedItem.productName)
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("A useful starting point, with the estimate kept visible.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var valueBlock: some View {
        CafadeGlassCard(tint: CafadePalette.saffron.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedItem.value.kind.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CafadePalette.accentText)
                    Spacer()
                    CafadePill(title: selectedItem.servingTitle(for: unitSystem), color: CafadePalette.mint)
                }
                Text(selectedItem.value.scaled(by: multiplier).displayText)
                    .font(
                        dynamicTypeSize.isAccessibilitySize
                            ? .system(.largeTitle, design: .rounded).weight(.medium)
                            : .system(size: 44, weight: .medium, design: .rounded)
                    )
                    .monospacedDigit()
                    .foregroundStyle(CafadePalette.paper)
                Text("This estimate is based on the US recipe. Actual caffeine may vary by size and preparation.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }

    @ViewBuilder
    private var sizeBlock: some View {
        if variants.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("SIZE")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(CafadePalette.accentText)
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(variants) { variant in
                            Button {
                                selectedItemID = variant.id
                            } label: {
                                Text(variant.servingTitle(for: unitSystem))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(variant.id == selectedItemID ? CafadePalette.ink : CafadePalette.paper)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(variant.id == selectedItemID ? CafadePalette.saffron : CafadePalette.paper.opacity(0.08), in: Capsule())
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        } else {
            infoRow(title: "Available size", value: selectedItem.servingTitle(for: unitSystem), symbol: "ruler")
        }
    }

    private var multiplierBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW MUCH?")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.accentText)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 9) { multiplierButtons }
                VStack(spacing: 9) { multiplierButtons }
            }
        }
    }

    @ViewBuilder
    private var multiplierButtons: some View {
        ForEach([0.5, 1.0, 2.0], id: \.self) { value in
            Button {
                multiplier = value
            } label: {
                Text(value == 0.5 ? "0.5×" : value == 1.0 ? "1×" : "2×")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(multiplier == value ? CafadePalette.ink : CafadePalette.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(multiplier == value ? CafadePalette.saffron : CafadePalette.paper.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var timeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONSUMED AT")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.accentText)
            DatePicker("Consumed at", selection: $consumedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .tint(CafadePalette.saffron)
                .foregroundStyle(CafadePalette.paper)
        }
    }

    private var sourceBlock: some View {
        Link(destination: URL(string: selectedItem.sourceURL)!) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                    Text("Catalog source")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                Text("Verified \(CaffeineFormatter.date(selectedItem.verifiedAt))")
                    .font(.caption2)
            }
            .foregroundStyle(CafadePalette.mint)
        }
    }

    private func infoRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(CafadePalette.mint)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CafadePalette.paper)
        }
        .padding(16)
        .background(CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var isFinalValueValid: Bool {
        selectedItem.value
            .scaled(by: multiplier)
            .isValid(maximumMg: CaffeineCalculator.customEntryMaximumMg)
    }

    private func logNow() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let currentSettings = try (settings.first ?? AppServices.ensureSettings(in: modelContext))
            let outcome = try await services.log(
                value: selectedItem.value,
                catalogItemID: selectedItem.id,
                multiplier: multiplier,
                consumedAt: consumedAt,
                servingNote: selectedItem.servingTitle(for: unitSystem),
                sourceKind: .catalog,
                context: modelContext,
                settings: currentSettings
            )
            onLogged(outcome)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
