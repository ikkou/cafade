import AppIntents

struct LogCaffeineFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log caffeine"
    static let description = IntentDescription("Logs one of your recent Cafade drinks at the current time.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Drink")
    var drinkID: String

    init() {}

    init(drinkID: String) {
        self.drinkID = drinkID
    }

    func perform() async throws -> some IntentResult {
        _ = CafadeWidgetStore.logQuickDrink(id: drinkID)
        return .result()
    }
}
