import SwiftData
import SwiftUI

struct CustomDrinkEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query private var settings: [UserSettings]

    let draft: CustomDrinkDraft
    let onLogged: (IntakeMutationOutcome) -> Void
    @State private var name: String
    @State private var caffeineText: String
    @State private var servingNote: String
    @State private var consumedAt: Date
    @State private var multiplier = 1.0
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case name, caffeine, note }

    init(draft: CustomDrinkDraft, onLogged: @escaping (IntakeMutationOutcome) -> Void = { _ in }) {
        self.draft = draft
        self.onLogged = onLogged
        _name = State(initialValue: draft.name)
        _caffeineText = State(initialValue: draft.caffeineMg > 0 ? String(draft.caffeineMg) : "")
        _servingNote = State(initialValue: draft.servingNote)
        _consumedAt = State(initialValue: draft.consumedAt)
    }

    private var caffeineMg: Int? {
        guard let value = Int(caffeineText),
              (CaffeineCalculator.customEntryMinimumMg...CaffeineCalculator.customEntryMaximumMg).contains(value)
        else { return nil }
        return value
    }

    private var isValid: Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalValue = caffeineMg.map { Int((Double($0) * multiplier).rounded()) }
        return !normalizedName.isEmpty
            && normalizedName.count <= CaffeineCalculator.customNameMaximumLength
            && servingNote.trimmingCharacters(in: .whitespacesAndNewlines).count <= CaffeineCalculator.servingNoteMaximumLength
            && finalValue.map { (CaffeineCalculator.customEntryMinimumMg...CaffeineCalculator.customEntryMaximumMg).contains($0) } == true
    }

    var body: some View {
        ZStack {
            CafadeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom drink")
                            .font(.system(.title2, design: .serif).weight(.medium))
                            .foregroundStyle(CafadePalette.paper)
                        Text("Use the caffeine amount on a label, supplement panel, or medicine facts box.")
                            .font(.subheadline)
                            .foregroundStyle(CafadePalette.mist)
                    }

                    fieldCard(title: "NAME", symbol: "pencil") {
                        VStack(alignment: .trailing, spacing: 6) {
                            TextField("e.g. Afternoon coffee", text: $name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                            characterCount(name, maximum: CaffeineCalculator.customNameMaximumLength)
                        }
                    }

                    fieldCard(title: "CAFFEINE", symbol: "bolt.fill") {
                        HStack {
                            TextField("1–1,000", text: $caffeineText)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .caffeine)
                            Text("mg")
                                .foregroundStyle(CafadePalette.accentText)
                        }
                    }

                    fieldCard(title: "SERVING NOTE", symbol: "note.text") {
                        VStack(alignment: .trailing, spacing: 6) {
                            TextField("12 fl oz can", text: $servingNote)
                                .focused($focusedField, equals: .note)
                            characterCount(servingNote, maximum: CaffeineCalculator.servingNoteMaximumLength)
                        }
                    }

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

                    DatePicker("Consumed at", selection: $consumedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .tint(CafadePalette.saffron)
                        .foregroundStyle(CafadePalette.paper)

                    Button {
                        Task { await save() }
                    } label: {
                        Text(caffeineMg.map { "Log \(Int((Double($0) * multiplier).rounded())) mg" } ?? "Enter a caffeine amount")
                    }
                    .buttonStyle(CafadePrimaryButtonStyle())
                    .disabled(!isValid || isSaving)
                    .opacity(isValid ? 1 : 0.5)
                    .accessibilityIdentifier("customDrink.save")
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Custom drink")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
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

    private func fieldCard<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(CafadePalette.accentText)
            content()
                .font(.body)
                .foregroundStyle(CafadePalette.paper)
                .tint(CafadePalette.saffron)
                .padding(15)
                .background(CafadePalette.paper.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    private func characterCount(_ value: String, maximum: Int) -> some View {
        Text("\(value.count)/\(maximum)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(value.count > maximum ? CafadePalette.coral : CafadePalette.mist)
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

    private func save() async {
        guard let caffeineMg else { return }
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let currentSettings = try (settings.first ?? AppServices.ensureSettings(in: modelContext))
            let outcome = try await services.log(
                value: .approximate(caffeineMg),
                customName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                multiplier: multiplier,
                consumedAt: consumedAt,
                servingNote: servingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : servingNote,
                sourceKind: .custom,
                context: modelContext,
                settings: currentSettings
            )
            onLogged(outcome)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
