import XCTest
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

    func testCatalogServingLabelsFollowSelectedUnits() {
        let coldBrew = CaffeineCatalog.item(id: "starbucks.cold-brew.grande")

        XCTAssertEqual(coldBrew?.servingTitle(for: .usCustomary), "Grande / 16 fl oz")
        XCTAssertEqual(coldBrew?.servingTitle(for: .metric), "473 mL")
    }

    func testHalfQuantityKeepsRangeAndRoundsEachBound() {
        let value = CaffeineValue.range(113, 247, typical: 180).scaled(by: 0.5)

        XCTAssertEqual(value.displayText, "57–124 mg")
        XCTAssertEqual(value.typicalMg, 90)
    }
}
