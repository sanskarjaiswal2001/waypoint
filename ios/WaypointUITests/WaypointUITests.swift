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
        XCTAssertTrue(app.buttons["Explore map"].waitForExistence(timeout: 5))
        app.buttons["Explore map"].tap()
        XCTAssertTrue(app.buttons["Worlds"].waitForExistence(timeout: 10))
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
        for _ in 0..<5 { if app.staticTexts["0.3.0"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["0.3.0"].exists)
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
}
