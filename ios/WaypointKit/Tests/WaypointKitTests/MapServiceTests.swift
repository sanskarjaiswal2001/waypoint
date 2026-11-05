import Foundation
import XCTest
@testable import WaypointKit

final class MapServiceTests: XCTestCase {
    private let origin = Coordinate(latitude: 50, longitude: 10)
    private let destination = Coordinate(latitude: 50.01, longitude: 10.01)

    func testRoutingUsesDistinctRealTravelProfiles() throws {
        let car = try MapService.routeURL(from: origin, to: destination, mode: .car)
        XCTAssertEqual(car.host, "router.project-osrm.org")
        XCTAssertTrue(car.path.contains("/driving/10.0,50.0;10.01,50.01"))
        for mode in [TravelMode.motorcycle, .bicycle, .walk] {
            let url = try MapService.routeURL(from: origin, to: destination, mode: mode)
            XCTAssertEqual(url.host, "valhalla1.openstreetmap.de")
            let json = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            XCTAssertEqual(payload["costing"] as? String, mode.costing)
            XCTAssertEqual(payload["shape_format"] as? String, "polyline6")
        }
    }

    func testInvalidCoordinatesNeverReachRoutingEndpoint() {
        for invalid in [Coordinate(latitude: .nan, longitude: 0), Coordinate(latitude: 91, longitude: 0),
                        Coordinate(latitude: 0, longitude: .infinity)] {
            XCTAssertThrowsError(try MapService.routeURL(from: invalid, to: destination, mode: .car))
        }
    }

    func testPhotonCoordinateOrderAndDuplicatePlaces() throws {
        let feature: [String: Any] = ["geometry": ["coordinates": [10.0, 50.0]],
                                      "properties": ["name": "Public museum", "city": "Example town", "osm_id": 123, "osm_type": "N"]]
        let data = try JSONSerialization.data(withJSONObject: ["features": [feature, feature]])
        let places = try MapService.decodePlaces(data)
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].coordinate, origin)
        XCTAssertEqual(places[0].name, "Public museum")
    }

    func testMalformedPhotonResultsAreRejected() throws {
        let malformed: [String: Any] = ["geometry": ["coordinates": [200, 95]], "properties": ["name": "Invalid"]]
        XCTAssertThrowsError(try MapService.decodePlaces(JSONSerialization.data(withJSONObject: ["features": [malformed]])))
        XCTAssertThrowsError(try MapService.decodePlaces(Data("{}".utf8)))
    }

    func testPolylineDecoderRejectsTruncationOverflowAndOutOfRangeCoordinates() {
        for geometry in ["_", "~~~~~~~~~~~~~", "\n\n", "_c`|@_c`|@_"] {
            XCTAssertThrowsError(try RoutePreparation.decodePolyline6(geometry), geometry)
        }
    }

    func testPolylineSixPrecision() throws {
        XCTAssertEqual(try RoutePreparation.decodePolyline6("??_ibE_ibE"), [
            Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 0.1, longitude: 0.1)
        ])
    }

    func testRouteGetsUpcomingTurnVoiceAndBannerPrompts() throws {
        let prepared = try RoutePreparation.prepare(response())
        let route = try XCTUnwrap(JSONSerialization.jsonObject(with: prepared) as? [String: Any])
        let steps = try XCTUnwrap((route["legs"] as? [[String: Any]])?.first?["steps"] as? [[String: Any]])
        let voices = try XCTUnwrap(steps[0]["voiceInstructions"] as? [[String: Any]])
        XCTAssertEqual(voices.count, 2)
        XCTAssertEqual(voices[0]["announcement"] as? String, "In 180 metres, Turn left onto Example Road")
        XCTAssertEqual(voices[1]["distanceAlongGeometry"] as? Double, 35)
        let banners = try XCTUnwrap(steps[0]["bannerInstructions"] as? [[String: Any]])
        XCTAssertEqual((banners[0]["primary"] as? [String: Any])?["text"] as? String, "Turn left onto Example Road")
    }

    func testExistingVoiceInstructionsArePreserved() throws {
        let prepared = try RoutePreparation.prepare(response(existingVoice: true))
        let route = try XCTUnwrap(JSONSerialization.jsonObject(with: prepared) as? [String: Any])
        let steps = try XCTUnwrap((route["legs"] as? [[String: Any]])?.first?["steps"] as? [[String: Any]])
        XCTAssertEqual((steps[0]["voiceInstructions"] as? [[String: Any]])?.first?["announcement"] as? String, "Provider instruction")
    }
    func testGeneratedSpeechRespectsImperialUnitsWithoutChangingTriggerDistance() throws {
        for (imperial, phrase) in [(false, "In 180 metres"), (true, "In 600 feet")] {
            let prepared = try RoutePreparation.prepare(response(), imperial: imperial)
            let route = try XCTUnwrap(JSONSerialization.jsonObject(with: prepared) as? [String: Any])
            let steps = try XCTUnwrap((route["legs"] as? [[String: Any]])?.first?["steps"] as? [[String: Any]])
            let voices = try XCTUnwrap(steps[0]["voiceInstructions"] as? [[String: Any]])
            XCTAssertTrue((voices[0]["announcement"] as? String)?.hasPrefix(phrase) == true)
            XCTAssertEqual(voices[0]["distanceAlongGeometry"] as? Double, 180)
        }
    }

    func testNoRouteAndInvalidGeometryCannotBeNavigated() throws {
        XCTAssertThrowsError(try RoutePreparation.prepare(Data("{\"code\":\"NoRoute\"}".utf8)))
        XCTAssertThrowsError(try RoutePreparation.prepare(response(geometry: "_")))
        XCTAssertThrowsError(try RoutePreparation.prepare(response(distance: -1)))
        XCTAssertThrowsError(try RoutePreparation.prepare(response(distance: 0)))
    }

    func testRoutesFarFromRequestedEndpointsAreRejected() throws {
        XCTAssertThrowsError(try RoutePreparation.prepare(response(), expectedOrigin: origin, expectedDestination: destination))
        XCTAssertNoThrow(try RoutePreparation.prepare(response(), expectedOrigin: Coordinate(latitude: 0, longitude: 0),
                                                       expectedDestination: Coordinate(latitude: 0.1, longitude: 0.1)))
    }

    func testArrivalAndRoundaboutInstructions() {
        XCTAssertEqual(RoutePreparation.instruction(for: ["maneuver": ["type": "arrive"]]), "You have arrived at your destination")
        XCTAssertEqual(RoutePreparation.instruction(for: ["maneuver": ["type": "roundabout", "exit": 3], "name": "Example Road"]),
                       "At the roundabout, take exit 3 onto Example Road")
    }

    private func response(geometry: String = "??_ibE_ibE", distance: Double = 500, existingVoice: Bool = false) throws -> Data {
        var first: [String: Any] = ["distance": 400.0, "duration": 40.0, "geometry": geometry,
                                     "maneuver": ["type": "depart", "location": [0.0, 0.0]]]
        if existingVoice { first["voiceInstructions"] = [["announcement": "Provider instruction", "distanceAlongGeometry": 30.0]] }
        let second: [String: Any] = ["distance": 100.0, "duration": 10.0, "geometry": geometry, "name": "Example Road",
                                      "maneuver": ["type": "turn", "modifier": "left", "location": [0.1, 0.1]]]
        return try JSONSerialization.data(withJSONObject: ["code": "Ok", "routes": [[
            "distance": distance, "duration": 50.0, "geometry": geometry, "legs": [["steps": [first, second]]]
        ]]])
    }
}
