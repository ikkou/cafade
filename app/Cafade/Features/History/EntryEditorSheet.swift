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

    init(event: IntakeEvent) {
        self.event = event
        _customName = State(initialValue: event.customName ?? CaffeineCatalog.displayName(for: event))
        _caffeineText = State(initialValue: String(event.caffeineMg))
        _servingNote = State(initialValue: event.servingNote ?? "")
        _consumedAt = State(initialValue: event.consumedAt)
    }

    private var caffeineMg: Int? { Int(caffeineText).map { min(max($0, 0), 2_000) } }
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
                                TextField("mg", text: $caffeineText)
                                    .keyboardType(.numberPad)
                                Text("mg")
                                    .foregroundStyle(CafadePalette.saffron)
                            }
                        }

                        editorField(title: "SERVING NOTE") {
                            TextField("Optional note", text: $servingNote)
                        }

                        DatePicker("Consumed at", selection: $consumedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .tint(CafadePalette.saffron)
                            .foregroundStyle(CafadePalette.paper)

                        Button {
                            save()
                        } label: {
                            Text("Save changes")
                        }
                        .buttonStyle(CafadePrimaryButtonStyle())
                        .disabled(caffeineMg == nil || customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(caffeineMg == nil ? 0.5 : 1)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete this entry", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CafadeSecondaryButtonStyle())
                        .foregroundStyle(CafadePalette.coral)
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
                    delete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes the entry from Cafade. If Apple Health is connected, its Cafade sample is removed too.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.sourceKind == .catalog ? "CATALOG ENTRY" : "CUSTOM ENTRY")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.saffron)
            Text(CaffeineCatalog.displayName(for: event))
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            if event.isRange {
                Text("The original catalog value was a typical range. The range remains part of the estimate.")
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
                .foregroundStyle(CafadePalette.saffron)
            content()
                .padding(15)
                .background(CafadePalette.paper.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .foregroundStyle(CafadePalette.paper)
        }
    }

    private func save() {
        guard let caffeineMg else { return }
        let currentSettings = settings.first ?? AppServices.ensureSettings(in: modelContext)
        services.update(
            event: event,
            caffeineMg: caffeineMg,
            minMg: event.minMg,
            maxMg: event.maxMg,
            consumedAt: consumedAt,
            servingNote: servingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : servingNote,
            context: modelContext,
            settings: currentSettings
        )
        if isCustom {
            event.customName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        let currentSettings = settings.first ?? AppServices.ensureSettings(in: modelContext)
        services.delete(event: event, context: modelContext, settings: currentSettings)
        dismiss()
    }
}
