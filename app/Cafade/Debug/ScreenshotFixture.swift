#if DEBUG
import Foundation
import SwiftData

@MainActor
enum ScreenshotFixture {
    private static let launchArgument = "--cafade-screenshot-fixture"
    private static let logArgument = "--cafade-screenshot-log"
    private static let historyArgument = "--cafade-screenshot-history"
    private static let settingsArgument = "--cafade-screenshot-settings"
    private static let modelArgument = "--cafade-screenshot-model"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static var initiallyShowsLog: Bool {
        ProcessInfo.processInfo.arguments.contains(logArgument)
    }

    static var initiallyShowsModelExplanation: Bool {
        ProcessInfo.processInfo.arguments.contains(modelArgument)
    }

    static var initialTab: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(historyArgument) { return .history }
        if arguments.contains(settingsArgument) || arguments.contains(modelArgument) { return .settings }
        return .today
    }

    static func installIfRequested(in context: ModelContext, now: Date = .now) throws {
        guard isRequested else { return }

        for event in try context.fetch(FetchDescriptor<IntakeEvent>()) {
            context.delete(event)
        }
        for settings in try context.fetch(FetchDescriptor<UserSettings>()) {
            context.delete(settings)
        }

        context.insert(
            UserSettings(
                marketCode: "US",
                languageCode: "en-US",
                unitSystem: .usCustomary,
                halfLifeHours: 4,
                dailyTargetMg: 80,
                typicalBedtimeMinutes: 23 * 60,
                reduceMotionOverride: false,
                healthKitWriteEnabled: false
            )
        )

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        // Keep today's three logs close enough to "now" to produce a clear,
        // layered curve while staying under the 450 mg contextual prompt.
        insertCatalogEvent(id: "generic.brewed-coffee", at: now.addingTimeInterval(-2.5 * 3_600), in: context)
        insertCatalogEvent(id: "starbucks.cold-brew.grande", at: now.addingTimeInterval(-1.35 * 3_600), in: context)
        insertCatalogEvent(id: "generic.green-tea", at: now.addingTimeInterval(-0.28 * 3_600), in: context)

        let morningIDs = [
            "generic.brewed-coffee",
            "starbucks.latte.grande",
            "starbucks.cold-brew.grande",
            "starbucks.americano.grande"
        ]
        let middayIDs = ["generic.black-tea", "generic.green-tea", "coca-cola.zero.12"]

        for dayOffset in 1...20 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: startOfToday),
                  let morning = calendar.date(byAdding: .minute, value: 8 * 60 + 10 + (dayOffset % 4) * 12, to: day),
                  let midday = calendar.date(byAdding: .minute, value: 12 * 60 + 20 + (dayOffset % 3) * 17, to: day)
            else { continue }

            insertCatalogEvent(id: morningIDs[dayOffset % morningIDs.count], at: morning, in: context)
            insertCatalogEvent(id: middayIDs[dayOffset % middayIDs.count], at: midday, in: context)

            if dayOffset.isMultiple(of: 3),
               let afternoon = calendar.date(byAdding: .minute, value: 15 * 60 + 5, to: day) {
                insertCatalogEvent(id: "redbull.original.8-4", at: afternoon, in: context)
            }
        }

        UserDefaults.standard.set(true, forKey: "cafade.hasShownHealthPrompt")
        try context.save()
    }

    private static func insertCatalogEvent(id: String, at consumedAt: Date, in context: ModelContext) {
        guard let item = CaffeineCatalog.item(id: id) else { return }
        context.insert(
            IntakeEvent(
                catalogItemID: item.id,
                caffeineMg: item.value.typicalMg,
                minMg: item.value.minMg,
                maxMg: item.value.maxMg,
                valueKind: item.value.kind,
                consumedAt: consumedAt,
                consumedTimeZoneIdentifier: TimeZone.current.identifier,
                servingNote: item.servingTitle(for: .usCustomary),
                sourceKind: .catalog,
                createdAt: consumedAt,
                updatedAt: consumedAt
            )
        )
    }
}
#endif
