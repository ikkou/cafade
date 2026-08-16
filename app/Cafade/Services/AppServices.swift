import Foundation
import Observation
import SwiftData

enum AppServiceError: LocalizedError {
    case settingsUnavailable
    case futureDate
    case invalidMultiplier
    case invalidCaffeineAmount
    case invalidName
    case nameTooLong
    case servingNoteTooLong
    case persistenceFailed
    case healthSyncIncomplete(Int)

    var errorDescription: String? {
        switch self {
        case .settingsUnavailable:
            "Cafade could not open its settings. Please try again."
        case .futureDate:
            "Choose a consumed time that is not in the future."
        case .invalidMultiplier:
            "Choose 0.5×, 1×, or 2×."
        case .invalidCaffeineAmount:
            "The final caffeine amount must be between 1 and 1,000 mg."
        case .invalidName:
            "Enter a name for this custom drink."
        case .nameTooLong:
            "Keep the drink name to 80 characters or fewer."
        case .servingNoteTooLong:
            "Keep the serving note to 120 characters or fewer."
        case .persistenceFailed:
            "Cafade could not save this change. Your previous data is unchanged. Please try again."
        case .healthSyncIncomplete(let failedCount):
            "Cafade connected to Apple Health, but \(failedCount) saved entr\(failedCount == 1 ? "y" : "ies") could not be synced. Your Cafade log is unchanged."
        }
    }
}

struct IntakeMutationOutcome {
    let event: IntakeEvent?
    let healthWarning: String?
}

@MainActor
@Observable
final class AppServices {
    let healthKit = HealthKitService()

    private static let pendingHealthDeletionIDsKey = "cafade.pendingHealthDeletionIDs"
    private static let pendingHealthDeleteAllKey = "cafade.pendingHealthDeleteAll"

    private(set) var hasPendingHealthCleanup: Bool

    init() {
        hasPendingHealthCleanup = UserDefaults.standard.bool(forKey: Self.pendingHealthDeleteAllKey)
            || !Self.pendingHealthDeletionIDs.isEmpty
    }

    static func ensureSettings(in context: ModelContext) throws -> UserSettings {
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            if let existing = try context.fetch(descriptor).first {
                if existing.normalizeForCurrentVersion() {
                    try context.save()
                }
                return existing
            }

            let settings = UserSettings()
            context.insert(settings)
            try context.save()
            return settings
        } catch {
            context.rollback()
            throw AppServiceError.settingsUnavailable
        }
    }

    static func saveSettings(in context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppServiceError.persistenceFailed
        }
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
    ) async throws -> IntakeMutationOutcome {
        let normalizedName = try validatedName(customName, sourceKind: sourceKind)
        let normalizedNote = try validatedServingNote(servingNote)
        let scaled = try validated(value: value, multiplier: multiplier, consumedAt: consumedAt)
        let event = IntakeEvent(
            catalogItemID: catalogItemID,
            customName: normalizedName,
            caffeineMg: scaled.typicalMg,
            minMg: scaled.minMg,
            maxMg: scaled.maxMg,
            valueKind: scaled.kind,
            quantityMultiplier: multiplier,
            consumedAt: consumedAt,
            consumedTimeZoneIdentifier: TimeZone.current.identifier,
            servingNote: normalizedNote,
            sourceKind: sourceKind
        )

        context.insert(event)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppServiceError.persistenceFailed
        }

        let warning = await writeToHealthIfNeeded(event: event, settings: settings)
        return IntakeMutationOutcome(event: event, healthWarning: warning)
    }

    func update(
        event: IntakeEvent,
        value: CaffeineValue,
        customName: String?,
        consumedAt: Date,
        servingNote: String?,
        context: ModelContext,
        settings: UserSettings
    ) async throws -> IntakeMutationOutcome {
        let normalizedName = try validatedName(customName, sourceKind: event.sourceKind)
        let normalizedNote = try validatedServingNote(servingNote)
        let validatedValue = try validated(value: value, multiplier: 1, consumedAt: consumedAt)

        event.customName = normalizedName
        event.caffeineMg = validatedValue.typicalMg
        event.minMg = validatedValue.minMg
        event.maxMg = validatedValue.maxMg
        event.valueKind = validatedValue.kind
        event.quantityMultiplier = 1
        event.consumedAt = consumedAt
        event.consumedTimeZoneIdentifier = TimeZone.current.identifier
        event.servingNote = normalizedNote
        event.markUpdated()

        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppServiceError.persistenceFailed
        }

        var warning: String?
        if settings.healthKitWriteEnabled {
            do {
                try await healthKit.replace(event: event)
            } catch {
                warning = "Saved in Cafade, but Apple Health could not update this entry. Reconnect Apple Health in Settings to retry."
            }
        }
        return IntakeMutationOutcome(event: event, healthWarning: warning)
    }

    func delete(
        event: IntakeEvent,
        context: ModelContext,
        settings: UserSettings
    ) async throws -> IntakeMutationOutcome {
        let eventID = event.id
        context.delete(event)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppServiceError.persistenceFailed
        }

        var warning: String?
        if settings.healthKitWriteEnabled {
            do {
                try await healthKit.deleteSamples(for: eventID)
                removePendingHealthDeletion(eventID)
            } catch {
                addPendingHealthDeletion(eventID)
                warning = "Deleted from Cafade, but Apple Health could not remove its copy. Retry Health cleanup in Settings."
            }
        }
        return IntakeMutationOutcome(event: nil, healthWarning: warning)
    }

    func deleteAll(
        events: [IntakeEvent],
        context: ModelContext,
        settings: UserSettings
    ) async throws -> IntakeMutationOutcome {
        let shouldCleanHealth = settings.healthKitWriteEnabled || hasPendingHealthCleanup
        for event in events {
            context.delete(event)
        }
        settings.resetToDefaults()

        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppServiceError.persistenceFailed
        }

        CafadeWidgetStore.clear()

        UserDefaults.standard.removeObject(forKey: "cafade.hasShownHealthPrompt")

        guard shouldCleanHealth else {
            return IntakeMutationOutcome(event: nil, healthWarning: nil)
        }

        do {
            try await healthKit.deleteAllCafadeSamples()
            clearPendingHealthCleanup()
            return IntakeMutationOutcome(event: nil, healthWarning: nil)
        } catch {
            UserDefaults.standard.set(true, forKey: Self.pendingHealthDeleteAllKey)
            refreshPendingHealthCleanupState()
            return IntakeMutationOutcome(
                event: nil,
                healthWarning: "Local Cafade data was deleted, but Apple Health cleanup is still pending. You can retry it in Settings."
            )
        }
    }

    func requestHealthKitAndSync(
        events: [IntakeEvent],
        settings: UserSettings,
        context: ModelContext
    ) async throws {
        try await healthKit.requestAuthorization()
        settings.healthKitWriteEnabled = true
        try Self.saveSettings(in: context)

        _ = await retryPendingHealthCleanup()
        var failedCount = 0
        for event in events {
            do {
                try await healthKit.replace(event: event)
            } catch {
                failedCount += 1
            }
        }
        if failedCount > 0 {
            throw AppServiceError.healthSyncIncomplete(failedCount)
        }
    }

    func retryPendingHealthCleanup() async -> String? {
        do {
            if UserDefaults.standard.bool(forKey: Self.pendingHealthDeleteAllKey) {
                try await healthKit.deleteAllCafadeSamples()
                clearPendingHealthCleanup()
                return nil
            }

            var remaining: [String] = []
            for idString in Self.pendingHealthDeletionIDs {
                guard let id = UUID(uuidString: idString) else { continue }
                do {
                    try await healthKit.deleteSamples(for: id)
                } catch {
                    remaining.append(idString)
                }
            }
            Self.pendingHealthDeletionIDs = remaining
            refreshPendingHealthCleanupState()
            return remaining.isEmpty
                ? nil
                : "Some Apple Health entries still could not be removed. Check Health access and try again."
        } catch {
            refreshPendingHealthCleanupState()
            return "Apple Health cleanup could not finish. Check Health access and try again."
        }
    }

    private func validated(
        value: CaffeineValue,
        multiplier: Double,
        consumedAt: Date
    ) throws -> CaffeineValue {
        guard consumedAt <= Date.now else { throw AppServiceError.futureDate }
        guard multiplier.isFinite, [0.5, 1.0, 2.0].contains(multiplier) else {
            throw AppServiceError.invalidMultiplier
        }
        let scaled = value.scaled(by: multiplier)
        guard scaled.isValid(maximumMg: CaffeineCalculator.customEntryMaximumMg) else {
            throw AppServiceError.invalidCaffeineAmount
        }
        return scaled
    }

    private func validatedName(_ name: String?, sourceKind: IntakeSourceKind) throws -> String? {
        guard sourceKind == .custom else { return name?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let normalized = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else { throw AppServiceError.invalidName }
        guard normalized.count <= CaffeineCalculator.customNameMaximumLength else {
            throw AppServiceError.nameTooLong
        }
        return normalized
    }

    private func validatedServingNote(_ note: String?) throws -> String? {
        let normalized = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard normalized.count <= CaffeineCalculator.servingNoteMaximumLength else {
            throw AppServiceError.servingNoteTooLong
        }
        return normalized.isEmpty ? nil : normalized
    }

    private func writeToHealthIfNeeded(event: IntakeEvent, settings: UserSettings) async -> String? {
        guard settings.healthKitWriteEnabled else { return nil }
        do {
            try await healthKit.write(event: event)
            return nil
        } catch {
            return "Saved in Cafade, but Apple Health could not add this entry. Reconnect Apple Health in Settings to retry."
        }
    }

    private static var pendingHealthDeletionIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: pendingHealthDeletionIDsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: pendingHealthDeletionIDsKey) }
    }

    private func addPendingHealthDeletion(_ id: UUID) {
        var values = Self.pendingHealthDeletionIDs
        if !values.contains(id.uuidString) {
            values.append(id.uuidString)
            Self.pendingHealthDeletionIDs = values
        }
        refreshPendingHealthCleanupState()
    }

    private func removePendingHealthDeletion(_ id: UUID) {
        var values = Self.pendingHealthDeletionIDs
        values.removeAll { $0 == id.uuidString }
        Self.pendingHealthDeletionIDs = values
        refreshPendingHealthCleanupState()
    }

    private func clearPendingHealthCleanup() {
        UserDefaults.standard.removeObject(forKey: Self.pendingHealthDeleteAllKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingHealthDeletionIDsKey)
        refreshPendingHealthCleanupState()
    }

    private func refreshPendingHealthCleanupState() {
        hasPendingHealthCleanup = UserDefaults.standard.bool(forKey: Self.pendingHealthDeleteAllKey)
            || !Self.pendingHealthDeletionIDs.isEmpty
    }
}
