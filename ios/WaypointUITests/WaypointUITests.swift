import XCTest

final class WaypointUITests: XCTestCase {
    func testFirstLaunchWorldSelectionAndMapPanels() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-waypoint-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Skip introduction"].waitForExistence(timeout: 15))
        let welcome = XCTAttachment(screenshot: app.screenshot())
        welcome.name = "Welcome"
        welcome.lifetime = .keepAlways
        add(welcome)

        app.buttons["Skip introduction"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Open map"].tap()
        XCTAssertTrue(app.buttons["Worlds"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Explore map"].exists)
        app.buttons["Worlds"].tap()
        let oldWest = app.buttons["OLD WEST, Red Dead Redemption 2"]
        XCTAssertTrue(oldWest.waitForExistence(timeout: 5))
        oldWest.tap()
        XCTAssertTrue(app.buttons["Search places"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Locate"].exists)
        app.buttons["Search places"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Saved"].tap()
        XCTAssertTrue(app.navigationBars["Your places"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Spoken directions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Miles and feet"].exists)
        let version = app.descendants(matching: .any).matching(identifier: "app-version").firstMatch
        for _ in 0..<8 { if version.exists && version.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        XCTAssertTrue(version.label.contains("0.3.0"))
        for _ in 0..<5 { if app.buttons["Replay introduction"].isHittable { break }; app.swipeDown() }
        app.buttons["Replay introduction"].tap()
        XCTAssertTrue(app.buttons["Skip introduction"].waitForExistence(timeout: 5))
        app.buttons["Skip introduction"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Open map"].tap()
        XCTAssertTrue(app.buttons["Search places"].waitForExistence(timeout: 5))
        let map = XCTAttachment(screenshot: app.screenshot())
        map.name = "Themed map"
        map.lifetime = .keepAlways
        add(map)
    }
    func testLargeTextDestinationKeepsPrimaryActionReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-waypoint-ui-testing", "-waypoint-route-layout-fixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let preview = app.buttons["Preview route"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.isHittable)
        app.swipeUp()
        XCTAssertTrue(preview.isHittable)
    }
    func testQuestsExplicitCompletionUndoAndSavedRenameSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-waypoint-ui-testing", "-waypoint-skip-intro", "-waypoint-places-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["Quests"].waitForExistence(timeout: 10))
        app.buttons["Quests"].tap()
        app.buttons["Add a quest"].tap()
        let title = app.textFields["Quest title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Example task")
        app.buttons["Save quest"].tap()
        XCTAssertTrue(app.buttons["Complete quest"].waitForExistence(timeout: 5))
        app.buttons["Complete quest"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.staticTexts["Example task"].exists)
        app.buttons["Done"].tap()
        app.buttons["Saved"].tap()
        let place = app.buttons["place-public-museum"]
        XCTAssertTrue(place.waitForExistence(timeout: 5))
        place.press(forDuration: 1.2)
        app.buttons["Rename"].tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Example public museum".count) + "Example work")
        app.alerts.buttons["Save name"].tap()
        app.terminate()
        app.launchArguments += ["-waypoint-preserve-preferences"]
        app.launch()
        app.buttons["Saved"].tap()
        let renamed = app.buttons["place-public-museum"]
        XCTAssertTrue(renamed.waitForExistence(timeout: 5))
        XCTAssertTrue(renamed.label.contains("Example work"))
        app.buttons["Done"].tap()
        app.buttons["Quests"].tap()
        XCTAssertTrue(app.staticTexts["Example task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Complete quest"].exists)
    }
    func testUpgradeNotesAppearOnceAndStayDismissedAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-waypoint-ui-testing", "-waypoint-upgrade-fixture"]
        app.launch()
        XCTAssertTrue(app.navigationBars["What's new"].waitForExistence(timeout: 15))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Quests"].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments += ["-waypoint-preserve-preferences"]
        app.launch()
        XCTAssertTrue(app.buttons["Quests"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["What's new"].exists)
    }
}
