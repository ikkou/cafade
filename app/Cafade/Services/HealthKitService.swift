import Foundation
import HealthKit

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device."
        case .authorizationDenied:
            "Cafade cannot write to Apple Health yet. In the Health app, open Summary > your profile > Apps > Cafade, turn on Dietary Caffeine, then try again."
        case .saveFailed:
            "Cafade could not save this caffeine entry to Apple Health."
        }
    }
}

@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    private var caffeineType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable() && caffeineType != nil
    }

    var authorizationStatus: HKAuthorizationStatus {
        guard isAvailable, let caffeineType else { return .sharingDenied }
        return store.authorizationStatus(for: caffeineType)
    }

    var isWriteAuthorized: Bool { isAvailable && authorizationStatus == .sharingAuthorized }
    var isWriteDenied: Bool { isAvailable && authorizationStatus == .sharingDenied }

    func requestAuthorization() async throws {
        guard isAvailable, let caffeineType else {
            throw HealthKitServiceError.unavailable
        }
        guard authorizationStatus != .sharingDenied else {
            throw HealthKitServiceError.authorizationDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [caffeineType], read: []) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    if self.store.authorizationStatus(for: caffeineType) == .sharingAuthorized {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HealthKitServiceError.authorizationDenied)
                    }
                } else {
                    continuation.resume(throwing: HealthKitServiceError.authorizationDenied)
                }
            }
        }
    }

    func write(event: IntakeEvent) async throws {
        guard isAvailable, let caffeineType else {
            throw HealthKitServiceError.unavailable
        }
        guard isWriteAuthorized else {
            throw HealthKitServiceError.authorizationDenied
        }

        let quantity = HKQuantity(unit: .gramUnit(with: .milli), doubleValue: Double(event.caffeineMg))
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: event.id.uuidString,
            HKMetadataKeySyncIdentifier: event.id.uuidString,
            HKMetadataKeySyncVersion: event.healthKitSyncVersion,
            HKMetadataKeyTimeZone: event.consumedTimeZoneIdentifier ?? TimeZone.current.identifier,
            "CafadeSource": "Cafade"
        ]
        let sample = HKQuantitySample(
            type: caffeineType,
            quantity: quantity,
            start: event.consumedAt,
            end: event.consumedAt,
            metadata: metadata
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.saveFailed)
                }
            }
        }
    }

    func replace(event: IntakeEvent) async throws {
        // HealthKit replaces the object with the same sync identifier when the
        // incoming sync version is newer. This works with write-only access and
        // avoids asking for read permission only to edit Cafade's own sample.
        try await write(event: event)
    }

    func deleteSamples(for eventID: UUID) async throws {
        try await deleteSamples(for: eventID.uuidString)
    }

    func deleteAllCafadeSamples() async throws {
        guard isAvailable, let caffeineType else {
            throw HealthKitServiceError.unavailable
        }

        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: "CafadeSource",
            operatorType: .equalTo,
            value: "Cafade"
        )
        try await deleteObjects(of: caffeineType, matching: predicate)
    }

    private func deleteSamples(for externalID: String) async throws {
        guard isAvailable, let caffeineType else {
            throw HealthKitServiceError.unavailable
        }

        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            operatorType: .equalTo,
            value: externalID
        )
        try await deleteObjects(of: caffeineType, matching: predicate)
    }

    private func deleteObjects(of type: HKObjectType, matching predicate: NSPredicate) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.deleteObjects(of: type, predicate: predicate) { success, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.saveFailed)
                }
            }
        }
    }
}
