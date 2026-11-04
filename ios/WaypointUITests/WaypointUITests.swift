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
        app.buttons["Worlds"].tap()
        let oldWest = app.buttons["OLD WEST"]
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
        XCTAssertTrue(app.staticTexts["0.2.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Spoken directions"].exists)
        XCTAssertTrue(app.switches["Miles and feet"].exists)
        app.buttons["Done"].tap()
        let map = XCTAttachment(screenshot: app.screenshot())
        map.name = "Old West map"
        map.lifetime = .keepAlways
        add(map)
    }
}
