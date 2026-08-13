import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppServices {
    let healthKit = HealthKitService()

    static func ensureSettings(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let settings = UserSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }

    func log(
        value: CaffeineValue,
        catalogItemID: String? = nil,
        customName: String? = nil,
        multiplier: Double = 1.0,
        consumedAt: Date,
        servingNote: String? = nil,
        sourceKind: IntakeSourceKind,
        context: ModelContext,
        settings: UserSettings
    ) -> IntakeEvent? {
        guard consumedAt <= .now else { return nil }
        let scaled = value.scaled(by: multiplier)
        let event = IntakeEvent(
            catalogItemID: catalogItemID,
            customName: customName,
            caffeineMg: scaled.typicalMg,
            minMg: scaled.minMg,
            maxMg: scaled.maxMg,
            quantityMultiplier: multiplier,
            consumedAt: consumedAt,
            servingNote: servingNote,
            sourceKind: sourceKind
        )
        context.insert(event)
        try? context.save()
        syncHealthKitIfNeeded(event: event, settings: settings)
        return event
    }

    func update(
        event: IntakeEvent,
        caffeineMg: Int,
        minMg: Int?,
        maxMg: Int?,
        consumedAt: Date,
        servingNote: String?,
        context: ModelContext,
        settings: UserSettings
    ) {
        guard consumedAt <= .now else { return }
        event.caffeineMg = caffeineMg
        event.minMg = minMg
        event.maxMg = maxMg
        event.consumedAt = consumedAt
        event.servingNote = servingNote
        event.updatedAt = .now
        try? context.save()

        guard settings.healthKitWriteEnabled else { return }
        Task {
            try? await healthKit.replace(event: event)
        }
    }

    func delete(event: IntakeEvent, context: ModelContext, settings: UserSettings) {
        let eventID = event.id
        context.delete(event)
        try? context.save()

        guard settings.healthKitWriteEnabled else { return }
        Task {
            try? await healthKit.deleteSamples(for: eventID)
        }
    }

    func deleteAll(events: [IntakeEvent], context: ModelContext, settings: UserSettings) {
        for event in events {
            context.delete(event)
        }
        settings.resetToDefaults()
        try? context.save()

        UserDefaults.standard.removeObject(forKey: "cafade.hasShownHealthPrompt")

        Task {
            try? await healthKit.deleteAllCafadeSamples()
        }
    }

    func requestHealthKitAndSync(
        events: [IntakeEvent],
        settings: UserSettings,
        context: ModelContext
    ) async throws {
        try await healthKit.requestAuthorization()
        settings.healthKitWriteEnabled = true
        try? context.save()
        for event in events {
            try? await healthKit.replace(event: event)
        }
    }

    private func syncHealthKitIfNeeded(event: IntakeEvent, settings: UserSettings) {
        guard settings.healthKitWriteEnabled else { return }
        Task {
            try? await healthKit.write(event: event)
        }
    }
}
