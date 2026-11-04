import XCTest

final class WaypointUITests: XCTestCase {
    func testFirstLaunchWorldSelectionAndMapPanels() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-waypoint-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Open map"].waitForExistence(timeout: 15))
        let welcome = XCTAttachment(screenshot: app.screenshot())
        welcome.name = "Welcome"
        welcome.lifetime = .keepAlways
        add(welcome)

        app.buttons.containing(.staticText, identifier: "Choose world").firstMatch.tap()
        let oldWest = app.buttons["OLD WEST"]
        XCTAssertTrue(oldWest.waitForExistence(timeout: 5))
        oldWest.tap()
        app.buttons["Open map"].tap()
        XCTAssertTrue(app.buttons["Search places"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["OLD WEST"].exists)
        app.buttons["Search places"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Saved"].tap()
        XCTAssertTrue(app.navigationBars["Your places"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["0.1.2"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let map = XCTAttachment(screenshot: app.screenshot())
        map.name = "Old West map"
        map.lifetime = .keepAlways
        add(map)
    }
}
