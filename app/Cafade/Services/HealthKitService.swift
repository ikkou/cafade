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
            "Cafade was not allowed to write caffeine to Apple Health."
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

    func requestAuthorization() async throws {
        guard isAvailable, let caffeineType else {
            throw HealthKitServiceError.unavailable
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

        let quantity = HKQuantity(unit: .gramUnit(with: .milli), doubleValue: Double(event.caffeineMg))
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: event.id.uuidString,
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
        try await deleteSamples(for: event.id.uuidString)
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

        let samples = try await fetchSamples(type: caffeineType, predicate: predicate)
        guard !samples.isEmpty else { return }
        try await delete(samples: samples)
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
        let samples = try await fetchSamples(type: caffeineType, predicate: predicate)
        guard !samples.isEmpty else { return }
        try await delete(samples: samples)
    }

    private func fetchSamples(
        type: HKSampleType,
        predicate: NSPredicate
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func delete(samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.delete(samples) { success, error in
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
