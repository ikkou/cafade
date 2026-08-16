import XCTest

final class CafadeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-cafade.hasShownHealthPrompt", "YES"]
        app.launch()
    }

    func testSettingsShortcutKeepsTabSelectionAndScreenInSync() {
        let settingsShortcut = app.buttons["today.openSettings"]
        XCTAssertTrue(settingsShortcut.waitForExistence(timeout: 5))
        settingsShortcut.tap()

        XCTAssertTrue(app.staticTexts["YOUR SETUP"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Settings"].isSelected)

        app.tabBars.buttons["Today"].tap()

        XCTAssertTrue(app.staticTexts["TODAY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
        XCTAssertFalse(app.staticTexts["YOUR SETUP"].exists)
    }

    func testSuggestedDrinkLogsWithoutFocusingSearch() {
        let logButton = app.buttons["today.logCaffeine"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        logButton.tap()

        let logNavigation = app.navigationBars["Log caffeine"]
        XCTAssertTrue(logNavigation.waitForExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 0)

        let coldBrew = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Starbucks Cold Brew")
        ).firstMatch
        XCTAssertTrue(coldBrew.waitForExistence(timeout: 5))
        coldBrew.tap()

        XCTAssertTrue(logNavigation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["TODAY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 0)
    }

    func testModelExplanationIsReachableFromSettings() {
        let settingsShortcut = app.buttons["today.openSettings"]
        XCTAssertTrue(settingsShortcut.waitForExistence(timeout: 5))
        settingsShortcut.tap()

        let modelExplanation = app.buttons["settings.modelExplanation"]
        XCTAssertTrue(modelExplanation.waitForExistence(timeout: 5))
        XCTAssertEqual(modelExplanation.label, "How the model works")
        modelExplanation.tap()

        XCTAssertTrue(app.navigationBars["How the estimate works"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["THE MODEL"].exists)
        XCTAssertTrue(app.staticTexts["READ THE SOURCES"].exists)
    }

    func testShareCardSavesImageToPhotos() {
        let shareButton = app.buttons["Share your day"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()

        XCTAssertTrue(app.navigationBars["Share your day"].waitForExistence(timeout: 5))

        let saveButton = app.buttons["SAVE IMAGE"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        let renderingFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == YES"),
            object: saveButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [renderingFinished], timeout: 10), .completed)
        saveButton.tap()

        XCTAssertTrue(app.alerts["Saved to Photos"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your Cafade card is ready in Photos."].exists)
    }
}
