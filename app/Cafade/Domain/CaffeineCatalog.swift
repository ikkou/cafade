import Foundation

// Market data stays in one value-based catalog so a new product or region can
// be added without changing calculation, persistence, or SwiftUI code.
enum CaffeineCatalog {
    private static let verificationDate = ISO8601DateFormatter().date(from: "2026-08-01T00:00:00Z") ?? .now

    static let items: [CatalogDrink] = [
        CatalogDrink(
            id: "generic.brewed-coffee",
            marketCode: "US",
            brand: nil,
            productName: "Brewed Coffee",
            variant: nil,
            familyID: "generic.brewed-coffee",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .range(113, 247, typical: 180),
            sourceURL: "https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "generic.black-tea",
            marketCode: "US",
            brand: nil,
            productName: "Black Tea",
            variant: nil,
            familyID: "generic.black-tea",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .approximate(71),
            sourceURL: "https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "generic.green-tea",
            marketCode: "US",
            brand: nil,
            productName: "Green Tea",
            variant: nil,
            familyID: "generic.green-tea",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .approximate(37),
            sourceURL: "https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "generic.decaf-coffee",
            marketCode: "US",
            brand: nil,
            productName: "Decaf Coffee",
            variant: nil,
            familyID: "generic.decaf-coffee",
            servingLabel: "8 fl oz",
            servingMl: 237,
            value: .range(2, 15, typical: 8),
            sourceURL: "https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.blonde-roast.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Blonde Roast",
            variant: "hot",
            familyID: "starbucks.blonde-roast",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .range(315, 390, typical: 350),
            sourceURL: "https://www.starbucks.com/menu/drinks/hot-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.pike-place.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Pike Place Roast",
            variant: "hot",
            familyID: "starbucks.pike-place",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .range(315, 390, typical: 350),
            sourceURL: "https://www.starbucks.com/menu/drinks/hot-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.americano.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Caffè Americano",
            variant: "hot",
            familyID: "starbucks.americano",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(225),
            sourceURL: "https://www.starbucks.com/menu/product/406/hot/nutrition",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.latte.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Caffè Latte",
            variant: "hot",
            familyID: "starbucks.latte",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(150),
            sourceURL: "https://www.starbucks.com/menu/product/407/hot/nutrition",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.caramel-macchiato.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Caramel Macchiato",
            variant: "hot",
            familyID: "starbucks.caramel-macchiato",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(150),
            sourceURL: "https://www.starbucks.com/menu/product/415/hot/nutrition",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.cold-brew.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Cold Brew",
            variant: "iced",
            familyID: "starbucks.cold-brew",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(205),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.nitro-cold-brew.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Nitro Cold Brew",
            variant: "iced",
            familyID: "starbucks.nitro-cold-brew",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(280),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.iced-coffee.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Iced Coffee",
            variant: "iced",
            familyID: "starbucks.iced-coffee",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(185),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.iced-latte.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Iced Caffè Latte",
            variant: "iced",
            familyID: "starbucks.iced-latte",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(150),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.iced-shaken-espresso.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Iced Shaken Espresso",
            variant: "iced",
            familyID: "starbucks.iced-shaken-espresso",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(225),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.brown-sugar-oatmilk.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Iced Brown Sugar Oatmilk Shaken Espresso",
            variant: "iced",
            familyID: "starbucks.brown-sugar-oatmilk",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(255),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "starbucks.iced-mocha.grande",
            marketCode: "US",
            brand: "Starbucks",
            productName: "Iced Caffè Mocha",
            variant: "iced",
            familyID: "starbucks.iced-mocha",
            servingLabel: "Grande / 16 fl oz",
            servingMl: 473,
            value: .approximate(175),
            sourceURL: "https://www.starbucks.com/menu/drinks/cold-coffee",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "redbull.original.8-4",
            marketCode: "US",
            brand: "Red Bull",
            productName: "Original",
            variant: "energy drink",
            familyID: "redbull.original",
            servingLabel: "8.4 fl oz",
            servingMl: 249,
            value: .exact(80),
            sourceURL: "https://www.redbull.com/us-en/energydrink/questions/how-much-caffeine-is-in-a-can-of-red-bull-energy-drink",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "redbull.original.12",
            marketCode: "US",
            brand: "Red Bull",
            productName: "Original",
            variant: "energy drink",
            familyID: "redbull.original",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .exact(114),
            sourceURL: "https://www.redbull.com/us-en/energydrink/questions/how-much-caffeine-is-in-a-can-of-red-bull-energy-drink",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "redbull.original.16",
            marketCode: "US",
            brand: "Red Bull",
            productName: "Original",
            variant: "energy drink",
            familyID: "redbull.original",
            servingLabel: "16 fl oz",
            servingMl: 473,
            value: .exact(151),
            sourceURL: "https://www.redbull.com/us-en/energydrink/questions/how-much-caffeine-is-in-a-can-of-red-bull-energy-drink",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "redbull.original.20",
            marketCode: "US",
            brand: "Red Bull",
            productName: "Original",
            variant: "energy drink",
            familyID: "redbull.original",
            servingLabel: "20 fl oz",
            servingMl: 591,
            value: .exact(198),
            sourceURL: "https://www.redbull.com/us-en/energydrink/questions/how-much-caffeine-is-in-a-can-of-red-bull-energy-drink",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "monster.original-green.16",
            marketCode: "US",
            brand: "Monster",
            productName: "Original Green",
            variant: "energy drink",
            familyID: "monster.original-green",
            servingLabel: "16 fl oz",
            servingMl: 473,
            value: .exact(160),
            sourceURL: "https://www.monsterenergy.com/en-us/energy-drinks/monster-energy/original-green/",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "celsius.original.can",
            marketCode: "US",
            brand: "CELSIUS",
            productName: "Original",
            variant: "energy drink",
            familyID: "celsius.original",
            servingLabel: "1 can",
            servingMl: 355,
            value: .exact(200),
            sourceURL: "https://www.celsius.com/essential-facts/",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "celsius.essentials.can",
            marketCode: "US",
            brand: "CELSIUS",
            productName: "Essentials",
            variant: "energy drink",
            familyID: "celsius.essentials",
            servingLabel: "1 can",
            servingMl: 473,
            value: .exact(270),
            sourceURL: "https://www.celsius.com/essential-facts/",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "coca-cola.original.12",
            marketCode: "US",
            brand: "Coca-Cola",
            productName: "Original",
            variant: "soda",
            familyID: "coca-cola.original",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .exact(34),
            sourceURL: "https://www.coca-cola.com/us/en/about-us/faq/what-is-caffeine",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "coca-cola.zero.12",
            marketCode: "US",
            brand: "Coca-Cola",
            productName: "Zero Sugar",
            variant: "soda",
            familyID: "coca-cola.zero",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .exact(34),
            sourceURL: "https://www.coca-cola.com/us/en/about-us/faq/what-is-caffeine",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "diet-coke.original.12",
            marketCode: "US",
            brand: "Diet Coke",
            productName: "Original",
            variant: "soda",
            familyID: "diet-coke.original",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .exact(46),
            sourceURL: "https://www.coca-cola.com/us/en/about-us/faq/what-is-caffeine",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "pepsi.original.12",
            marketCode: "US",
            brand: "Pepsi",
            productName: "Original",
            variant: "soda",
            familyID: "pepsi.original",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .exact(38),
            sourceURL: "https://www.pepsi.com/faq",
            verifiedAt: verificationDate,
            isActive: true
        ),
        CatalogDrink(
            id: "diet-pepsi.original.12",
            marketCode: "US",
            brand: "Diet Pepsi",
            productName: "Original",
            variant: "soda",
            familyID: "diet-pepsi.original",
            servingLabel: "12 fl oz",
            servingMl: 355,
            value: .exact(35),
            sourceURL: "https://www.pepsi.com/faq",
            verifiedAt: verificationDate,
            isActive: true
        )
    ]

    static let suggestedIDs = [
        "starbucks.cold-brew.grande",
        "starbucks.americano.grande",
        "generic.brewed-coffee",
        "redbull.original.8-4",
        "diet-coke.original.12",
        "generic.green-tea"
    ]

    static func item(id: String?) -> CatalogDrink? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    static func suggested() -> [CatalogDrink] {
        suggestedIDs.compactMap(item(id:)).filter(\.isActive)
    }

    static func search(_ query: String) -> [CatalogDrink] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return suggested() }
        return items.filter { $0.isActive && $0.searchText.contains(normalized) }
    }

    static func variants(for familyID: String) -> [CatalogDrink] {
        items.filter { $0.isActive && $0.familyID == familyID }
            .sorted { $0.servingMl < $1.servingMl }
    }

    static func value(for event: IntakeEvent) -> CaffeineValue {
        if let catalog = item(id: event.catalogItemID) {
            return CaffeineValue(
                kind: catalog.value.kind,
                typicalMg: event.caffeineMg,
                minMg: event.minMg,
                maxMg: event.maxMg
            )
        }
        return event.value
    }

    static func displayName(for event: IntakeEvent) -> String {
        if let catalog = item(id: event.catalogItemID) {
            return catalog.title
        }
        return event.customName ?? "Custom drink"
    }
}
