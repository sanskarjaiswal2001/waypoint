import FerrostarCore
import FerrostarCoreFFI
import Foundation
import WaypointKit
import XCTest

final class NavigationContractTests: XCTestCase {
    func testPreparedPublicProviderResponseParsesIntoNavigableFerrostarRoute() throws {
        func step(_ type: String, distance: Double, modifier: String = "straight") -> [String: Any] {
            ["distance": distance, "duration": distance / 10, "geometry": "??_ibE_ibE",
             "name": "Example Road", "intersections": [],
             "maneuver": ["type": type, "modifier": modifier, "location": [0.0, 0.0],
                          "bearing_before": 0, "bearing_after": 0]]
        }
        let response: [String: Any] = ["code": "Ok", "routes": [[
            "distance": 500.0, "duration": 50.0, "geometry": "??_ibE_ibE",
            "legs": [["distance": 500.0, "duration": 50.0, "steps": [
                step("depart", distance: 400), step("turn", distance: 100, modifier: "left"), step("arrive", distance: 0)
            ]]]
        ]]]
        let prepared = try RoutePreparation.prepare(JSONSerialization.data(withJSONObject: response))
        let route = try createRouteFromOsrmRoute(routeData: prepared, waypoints: [
            Waypoint(coordinate: GeographicCoordinate(lat: 0, lng: 0), kind: .break),
            Waypoint(coordinate: GeographicCoordinate(lat: 0.1, lng: 0.1), kind: .break)
        ], polylinePrecision: 6)
        XCTAssertEqual(route.geometry.count, 2)
        XCTAssertEqual(route.geometry.last?.lat, 0.1)
        XCTAssertEqual(route.steps.count, 3)
        XCTAssertFalse(route.steps[0].spokenInstructions.isEmpty)
        XCTAssertEqual(route.steps[0].visualInstructions.first?.primaryContent.text, "Turn left onto Example Road")
        XCTAssertFalse(route.steps[0].instruction.contains("TODO"))
    }
}
