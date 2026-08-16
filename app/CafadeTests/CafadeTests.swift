import XCTest
import SwiftData
@testable import Cafade

final class CafadeTests: XCTestCase {
    func testHalfLifeReducesEstimateByHalf() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let event = IntakeEvent(
            caffeineMg: 200,
            consumedAt: start,
            sourceKind: .custom
        )

        let estimate = CaffeineCalculator.estimate(
            events: [event],
            at: start.addingTimeInterval(4 * 3600),
            halfLifeHours: 4
        )

        XCTAssertEqual(estimate.typicalMg, 100, accuracy: 0.01)
    }

    func testRangeIsPreservedThroughDecay() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let event = IntakeEvent(
            caffeineMg: 180,
            minMg: 113,
            maxMg: 247,
            consumedAt: start,
            sourceKind: .catalog
        )

        let estimate = CaffeineCalculator.estimate(
            events: [event],
            at: start,
            halfLifeHours: 4
        )

        XCTAssertEqual(estimate.minMg, 113, accuracy: 0.01)
        XCTAssertEqual(estimate.maxMg, 247, accuracy: 0.01)
        XCTAssertTrue(estimate.hasRange)
    }

    func testCatalogSearchIsExtensibleAndReturnsUSItems() {
        let results = CaffeineCatalog.search("starbucks")

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.marketCode == "US" && $0.isActive })
        XCTAssertTrue(results.contains { $0.id == "starbucks.cold-brew.grande" })
    }

    func testFutureEventsDoNotIncreaseCurrentEstimate() {
        let now = Date(timeIntervalSince1970: 3_000_000)
        let future = IntakeEvent(
            caffeineMg: 200,
            consumedAt: now.addingTimeInterval(3600),
            sourceKind: .custom
        )

        let estimate = CaffeineCalculator.estimate(events: [future], at: now, halfLifeHours: 4)

        XCTAssertEqual(estimate, .zero)
    }

    func testMultipleIntakesAreSummedAtTheCurrentTime() {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let earlier = IntakeEvent(
            caffeineMg: 120,
            consumedAt: now.addingTimeInterval(-2 * 3600),
            sourceKind: .custom
        )
        let later = IntakeEvent(
            caffeineMg: 80,
            consumedAt: now.addingTimeInterval(-45 * 60),
            sourceKind: .custom
        )

        let estimate = CaffeineCalculator.estimate(
            events: [earlier, later],
            at: now,
            halfLifeHours: 4
        )
        let expected = 120 * pow(0.5, 2.0 / 4.0) + 80 * pow(0.5, 0.75 / 4.0)

        XCTAssertEqual(estimate.typicalMg, expected, accuracy: 0.01)
        XCTAssertGreaterThan(estimate.typicalMg, 120 * pow(0.5, 2.0 / 4.0))
    }

    func testWidgetEstimateIncludesEveryIntakeAndUsesTheConfiguredHalfLife() {
        let now = Date(timeIntervalSince1970: 4_500_000)
        let events = [
            CafadeWidgetEvent(
                id: UUID(),
                name: "Coffee",
                catalogItemID: nil,
                caffeineMg: 120,
                minMg: nil,
                maxMg: nil,
                valueKindRaw: "approximate",
                sourceKindRaw: "custom",
                consumedAt: now.addingTimeInterval(-2 * 3_600)
            ),
            CafadeWidgetEvent(
                id: UUID(),
                name: "Espresso",
                catalogItemID: nil,
                caffeineMg: 80,
                minMg: nil,
                maxMg: nil,
                valueKindRaw: "approximate",
                sourceKindRaw: "custom",
                consumedAt: now.addingTimeInterval(-45 * 60)
            )
        ]
        let snapshot = CafadeWidgetSnapshot(
            events: events,
            quickDrinks: [],
            halfLifeHours: 4,
            updatedAt: now
        )
        let expected = 120 * pow(0.5, 2.0 / 4.0) + 80 * pow(0.5, 0.75 / 4.0)

        XCTAssertEqual(snapshot.estimate(at: now).typicalMg, expected, accuracy: 0.01)
    }

    func testWidgetQuickLogKeepsThreeDistinctMostRecentDrinks() {
        let now = Date(timeIntervalSince1970: 4_600_000)
        var snapshot = CafadeWidgetSnapshot(events: [], quickDrinks: [], halfLifeHours: 4, updatedAt: now)

        for (index, name) in ["Coffee", "Espresso", "Tea", "Cola"].enumerated() {
            snapshot.record(
                CafadeWidgetEvent(
                    id: UUID(),
                    name: name,
                    catalogItemID: nil,
                    caffeineMg: 50 + index,
                    minMg: nil,
                    maxMg: nil,
                    valueKindRaw: "approximate",
                    sourceKindRaw: "custom",
                    consumedAt: now.addingTimeInterval(Double(index))
                ),
                now: now.addingTimeInterval(Double(index))
            )
        }

        XCTAssertEqual(snapshot.quickDrinks.map(\.name), ["Cola", "Tea", "Espresso"])
    }

    @MainActor
    func testWidgetIntentQueuesTheSelectedDrinkWithoutOpeningTheApp() async throws {
        CafadeWidgetStore.clear()
        defer { CafadeWidgetStore.clear() }

        let drink = CafadeWidgetQuickDrink.defaults[0]
        CafadeWidgetStore.saveSnapshot(
            CafadeWidgetSnapshot(
                events: [],
                quickDrinks: [drink],
                halfLifeHours: 4,
                updatedAt: .now
            )
        )

        _ = try await LogCaffeineFromWidgetIntent(drinkID: drink.id).perform()

        let pending = CafadeWidgetStore.pendingEvents()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.name, drink.name)
        XCTAssertEqual(pending.first?.caffeineMg, drink.caffeineMg)
    }

    func testCatalogServingLabelsFollowSelectedUnits() {
        let coldBrew = CaffeineCatalog.item(id: "starbucks.cold-brew.grande")

        XCTAssertEqual(coldBrew?.servingTitle(for: .usCustomary), "Grande / 16 fl oz")
        XCTAssertEqual(coldBrew?.servingTitle(for: .metric), "473 mL")
    }

    func testAppDatesStayEnglishWhenTheDeviceLocaleDiffers() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12))
        )

        XCTAssertEqual(CaffeineFormatter.fullDay(date), "Saturday, August 15")
        XCTAssertEqual(CaffeineFormatter.weekday(date), "Sat")
    }

    func testLegacySettingsAreNormalizedWithoutTouchingIntakeData() {
        let settings = UserSettings(
            marketCode: "JP",
            languageCode: "ja-JP",
            halfLifeHours: 99,
            dailyTargetMg: 2_000,
            typicalBedtimeMinutes: 1_500
        )

        XCTAssertTrue(settings.normalizeForCurrentVersion())
        XCTAssertEqual(settings.marketCode, "US")
        XCTAssertEqual(settings.languageCode, "en-US")
        XCTAssertEqual(settings.halfLifeHours, 4)
        XCTAssertEqual(settings.dailyTargetMg, 1_000)
        XCTAssertNil(settings.typicalBedtimeMinutes)
        XCTAssertFalse(settings.normalizeForCurrentVersion())
    }

    func testHealthSyncVersionAlwaysAdvancesAcrossRapidEdits() {
        let timestamp = Date(timeIntervalSince1970: 8_000_000.123)
        let event = IntakeEvent(
            caffeineMg: 80,
            consumedAt: timestamp,
            sourceKind: .custom,
            updatedAt: timestamp
        )
        let originalVersion = event.healthKitSyncVersion

        event.markUpdated(at: timestamp)
        let firstEditVersion = event.healthKitSyncVersion
        event.markUpdated(at: timestamp.addingTimeInterval(-10))

        XCTAssertGreaterThan(firstEditVersion, originalVersion)
        XCTAssertGreaterThan(event.healthKitSyncVersion, firstEditVersion)
    }

    func testHalfQuantityKeepsRangeAndRoundsEachBound() {
        let value = CaffeineValue.range(113, 247, typical: 180).scaled(by: 0.5)

        XCTAssertEqual(value.displayText, "57–124 mg")
        XCTAssertEqual(value.typicalMg, 90)
    }

    func testDailyLoggedTotalUsesTheSelectedCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let start = calendar.startOfDay(for: day)
        let sameDay = IntakeEvent(caffeineMg: 275, consumedAt: start.addingTimeInterval(9 * 3600), sourceKind: .custom)
        let sameDayLater = IntakeEvent(caffeineMg: 180, consumedAt: start.addingTimeInterval(15 * 3600), sourceKind: .custom)
        let nextDay = IntakeEvent(caffeineMg: 900, consumedAt: start.addingTimeInterval(24 * 3600), sourceKind: .custom)

        let total = CaffeineCalculator.loggedTotalMg(
            on: day,
            events: [sameDay, sameDayLater, nextDay],
            calendar: calendar
        )

        XCTAssertEqual(total, 455)
        XCTAssertGreaterThan(total, CaffeineCalculator.gentleNudgeThresholdMg)
    }

    func testCustomEntryMaximumIsOneThousandMilligrams() {
        XCTAssertEqual(CaffeineCalculator.customEntryMaximumMg, 1_000)
    }

    func testOptimizedTimelineMatchesDirectEstimateAtEveryPoint() {
        let center = Date(timeIntervalSince1970: 5_000_000)
        let events = [
            IntakeEvent(caffeineMg: 180, minMg: 113, maxMg: 247, consumedAt: center.addingTimeInterval(-15 * 3600), sourceKind: .catalog),
            IntakeEvent(caffeineMg: 80, consumedAt: center.addingTimeInterval(-90 * 60), sourceKind: .custom),
            IntakeEvent(caffeineMg: 120, consumedAt: center.addingTimeInterval(3 * 3600), sourceKind: .custom)
        ]

        let timeline = CaffeineCalculator.timeline(
            events: events,
            centeredAt: center,
            halfLifeHours: 4,
            points: 49,
            spanHours: 24
        )

        for point in timeline {
            let direct = CaffeineCalculator.estimate(events: events, at: point.date, halfLifeHours: 4)
            XCTAssertEqual(point.estimate.typicalMg, direct.typicalMg, accuracy: 0.0001)
            XCTAssertEqual(point.estimate.minMg, direct.minMg, accuracy: 0.0001)
            XCTAssertEqual(point.estimate.maxMg, direct.maxMg, accuracy: 0.0001)
        }
    }

    func testCrossingDateUsesExactHalfLifeSolution() {
        let start = Date(timeIntervalSince1970: 6_000_000)
        let event = IntakeEvent(caffeineMg: 200, consumedAt: start, sourceKind: .custom)

        let crossing = CaffeineCalculator.crossingDate(
            events: [event],
            after: start,
            targetMg: 50,
            halfLifeHours: 4
        )

        XCTAssertEqual(crossing?.timeIntervalSince(start) ?? 0, 8 * 3600, accuracy: 0.001)
    }

    func testDailyTotalsIncludeDaysWithoutEntries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 7_000_000))
        let events = [
            IntakeEvent(caffeineMg: 100, consumedAt: start.addingTimeInterval(9 * 3600), sourceKind: .custom),
            IntakeEvent(caffeineMg: 150, consumedAt: start.addingTimeInterval(10 * 3600), sourceKind: .custom),
            IntakeEvent(caffeineMg: 300, consumedAt: start.addingTimeInterval(2 * 24 * 3600), sourceKind: .custom)
        ]
        let interval = DateInterval(
            start: start,
            end: start.addingTimeInterval(6 * 24 * 3600 + 23 * 3600)
        )

        let totals = CaffeineCalculator.dailyTotals(events: events, in: interval, calendar: calendar)

        XCTAssertEqual(totals.count, 7)
        XCTAssertEqual(totals.map(\.total), [250, 0, 300, 0, 0, 0, 0])
        XCTAssertEqual(totals.map(\.total).max(), 300)
    }

    func testStoredValueKindIsIndependentOfLaterCatalogChanges() {
        let event = IntakeEvent(
            catalogItemID: "generic.brewed-coffee",
            caffeineMg: 180,
            minMg: 113,
            maxMg: 247,
            valueKind: .range,
            consumedAt: .now,
            sourceKind: .catalog
        )

        XCTAssertEqual(event.value.kind, .range)
        XCTAssertEqual(CaffeineCatalog.value(for: event), .range(113, 247, typical: 180))
    }

    func testBundledCatalogDecodesAndPassesValidation() {
        XCTAssertEqual(CaffeineCatalog.items.count, 28)
        XCTAssertTrue(CaffeineCatalog.validationErrors().isEmpty)
        XCTAssertEqual(CaffeineCatalog.item(id: "starbucks.cold-brew.grande")?.value.typicalMg, 205)
    }

    func testShareSnapshotUsesAllDrinksAndActualCurve() {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: .now) ?? .now
        let start = calendar.startOfDay(for: date)
        let events = (0..<6).map { index in
            IntakeEvent(
                customName: "Drink \(index + 1)",
                caffeineMg: 50,
                valueKind: .approximate,
                consumedAt: start.addingTimeInterval(Double(index + 7) * 3600),
                sourceKind: .custom
            )
        }
        let estimate = CaffeineCalculator.estimate(events: events, at: date, halfLifeHours: 4)

        let snapshot = CafadeShareSnapshot(date: date, estimate: estimate, events: events, halfLifeHours: 4)

        XCTAssertEqual(snapshot.totalDrinkCount, 6)
        XCTAssertEqual(snapshot.totalLoggedMg, 300)
        XCTAssertEqual(snapshot.drinks.count, 4)
        XCTAssertEqual(snapshot.curveValues.count, 49)
        XCTAssertGreaterThan(snapshot.curveValues.max() ?? 0, 0)
        XCTAssertGreaterThan(CafadeShareCard.canvasHeight(for: snapshot), 1_120)
        XCTAssertLessThanOrEqual(CafadeShareCard.canvasHeight(for: snapshot), 1_280)
    }

    @MainActor
    func testServiceRejectsAmountAboveMaximumAfterMultiplier() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: IntakeEvent.self,
            UserSettings.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let settings = try AppServices.ensureSettings(in: context)
        let services = AppServices()

        do {
            _ = try await services.log(
                value: .approximate(600),
                customName: "Too much",
                multiplier: 2,
                consumedAt: .now,
                sourceKind: .custom,
                context: context,
                settings: settings
            )
            XCTFail("Expected the final 1,200 mg amount to be rejected")
        } catch AppServiceError.invalidCaffeineAmount {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(try context.fetch(FetchDescriptor<IntakeEvent>()).isEmpty)
    }

    @MainActor
    func testServiceRejectsInvalidCustomMetadataAndFutureDates() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: IntakeEvent.self,
            UserSettings.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let settings = try AppServices.ensureSettings(in: context)
        let services = AppServices()

        do {
            _ = try await services.log(
                value: .approximate(80),
                customName: "   ",
                consumedAt: .now,
                sourceKind: .custom,
                context: context,
                settings: settings
            )
            XCTFail("Expected a whitespace-only name to be rejected")
        } catch AppServiceError.invalidName {
            // Expected.
        }

        do {
            _ = try await services.log(
                value: .approximate(80),
                customName: String(repeating: "A", count: 81),
                consumedAt: .now,
                sourceKind: .custom,
                context: context,
                settings: settings
            )
            XCTFail("Expected an 81-character name to be rejected")
        } catch AppServiceError.nameTooLong {
            // Expected.
        }

        do {
            _ = try await services.log(
                value: .approximate(80),
                customName: "Coffee",
                consumedAt: .now,
                servingNote: String(repeating: "N", count: 121),
                sourceKind: .custom,
                context: context,
                settings: settings
            )
            XCTFail("Expected a 121-character serving note to be rejected")
        } catch AppServiceError.servingNoteTooLong {
            // Expected.
        }

        do {
            _ = try await services.log(
                value: .approximate(80),
                customName: "Coffee",
                consumedAt: Date.now.addingTimeInterval(60),
                sourceKind: .custom,
                context: context,
                settings: settings
            )
            XCTFail("Expected a future consumed time to be rejected")
        } catch AppServiceError.futureDate {
            // Expected.
        }

        XCTAssertTrue(try context.fetch(FetchDescriptor<IntakeEvent>()).isEmpty)
    }

    @MainActor
    func testServicePersistsRangeKindAndConsumedTimeZone() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: IntakeEvent.self,
            UserSettings.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let settings = try AppServices.ensureSettings(in: context)
        let services = AppServices()

        let outcome = try await services.log(
            value: .range(100, 160, typical: 130),
            catalogItemID: "test.range",
            consumedAt: .now,
            sourceKind: .catalog,
            context: context,
            settings: settings
        )

        XCTAssertEqual(outcome.event?.valueKind, .range)
        XCTAssertEqual(outcome.event?.minMg, 100)
        XCTAssertEqual(outcome.event?.maxMg, 160)
        XCTAssertEqual(outcome.event?.consumedTimeZoneIdentifier, TimeZone.current.identifier)
    }
}
