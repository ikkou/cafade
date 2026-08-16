import SwiftData
import SwiftUI

struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query private var settings: [UserSettings]

    let event: IntakeEvent
    @State private var customName: String
    @State private var caffeineText: String
    @State private var servingNote: String
    @State private var consumedAt: Date
    @State private var showingDeleteConfirmation = false
    @State private var message: String?
    @State private var dismissAfterMessage = false
    @State private var isWorking = false

    init(event: IntakeEvent) {
        self.event = event
        _customName = State(initialValue: event.customName ?? CaffeineCatalog.displayName(for: event))
        _caffeineText = State(initialValue: String(event.caffeineMg))
        _servingNote = State(initialValue: event.servingNote ?? "")
        _consumedAt = State(initialValue: event.consumedAt)
    }

    private var caffeineMg: Int? {
        guard let value = Int(caffeineText),
              (CaffeineCalculator.customEntryMinimumMg...CaffeineCalculator.customEntryMaximumMg).contains(value)
        else {
            return nil
        }
        return value
    }
    private var isCustom: Bool { event.sourceKind == .custom }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        if isCustom {
                            editorField(title: "NAME") {
                                TextField("Drink name", text: $customName)
                                    .textInputAutocapitalization(.words)
                            }
                        }

                        editorField(title: "TYPICAL CAFFEINE") {
                            HStack {
                                TextField("1–1,000", text: $caffeineText)
                                    .keyboardType(.numberPad)
                                Text("mg")
                                    .foregroundStyle(CafadePalette.accentText)
                            }
                        }

                        editorField(title: "SERVING NOTE") {
                            VStack(alignment: .trailing, spacing: 6) {
                                TextField("Optional note", text: $servingNote)
                                Text("\(servingNote.count)/\(CaffeineCalculator.servingNoteMaximumLength)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(
                                        servingNote.count > CaffeineCalculator.servingNoteMaximumLength
                                            ? CafadePalette.coral
                                            : CafadePalette.mist
                                    )
                            }
                        }

                        DatePicker("Consumed at", selection: $consumedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .tint(CafadePalette.saffron)
                            .foregroundStyle(CafadePalette.paper)

                        Button {
                            Task { await save() }
                        } label: {
                            Text("Save changes")
                        }
                        .buttonStyle(CafadePrimaryButtonStyle())
                        .disabled(!isValid || isWorking)
                        .opacity(caffeineMg == nil ? 0.5 : 1)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete this entry", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CafadeSecondaryButtonStyle())
                        .foregroundStyle(CafadePalette.coral)
                        .disabled(isWorking)
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await delete() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes the entry from Cafade. If Apple Health is connected, its Cafade sample is removed too.")
            }
            .alert(
                "Cafade",
                isPresented: Binding(
                    get: { message != nil },
                    set: { if !$0 { message = nil } }
                )
            ) {
                Button("OK") {
                    message = nil
                    if dismissAfterMessage { dismiss() }
                }
            } message: {
                Text(message ?? "")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isWorking)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.sourceKind == .catalog ? "CATALOG ENTRY" : "CUSTOM ENTRY")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.accentText)
            Text(CaffeineCatalog.displayName(for: event))
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            if event.isRange {
                Text("The original value is a range. If you change the amount, Cafade saves the new value as an approximation and removes the old range.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(CafadePalette.accentText)
            content()
                .padding(15)
                .background(CafadePalette.paper.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .foregroundStyle(CafadePalette.paper)
        }
    }

    private var isValid: Bool {
        guard caffeineMg != nil,
              servingNote.trimmingCharacters(in: .whitespacesAndNewlines).count <= CaffeineCalculator.servingNoteMaximumLength
        else { return false }
        if isCustom {
            let normalized = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            return !normalized.isEmpty && normalized.count <= CaffeineCalculator.customNameMaximumLength
        }
        return true
    }

    private func save() async {
        guard let caffeineMg else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let currentSettings = try (settings.first ?? AppServices.ensureSettings(in: modelContext))
            let value = caffeineMg == event.caffeineMg
                ? CaffeineCatalog.value(for: event)
                : CaffeineValue.approximate(caffeineMg)
            let outcome = try await services.update(
                event: event,
                value: value,
                customName: isCustom ? customName : event.customName,
                consumedAt: consumedAt,
                servingNote: servingNote,
                context: modelContext,
                settings: currentSettings
            )
            if let warning = outcome.healthWarning {
                dismissAfterMessage = true
                message = warning
            } else {
                dismiss()
            }
        } catch {
            dismissAfterMessage = false
            message = error.localizedDescription
        }
    }

    private func delete() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let currentSettings = try (settings.first ?? AppServices.ensureSettings(in: modelContext))
            let outcome = try await services.delete(event: event, context: modelContext, settings: currentSettings)
            if let warning = outcome.healthWarning {
                dismissAfterMessage = true
                message = warning
            } else {
                dismiss()
            }
        } catch {
            dismissAfterMessage = false
            message = error.localizedDescription
        }
    }
}
