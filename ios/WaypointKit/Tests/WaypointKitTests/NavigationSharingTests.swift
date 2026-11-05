import Foundation
import XCTest
@testable import WaypointKit

final class NavigationSharingTests: XCTestCase {
    func testAddressesCoordinatesAndGoogleDestinationsProduceProposals() {
        XCTAssertEqual(NavigationSharing.parseText("Example Museum"), .search("Example Museum"))
        XCTAssertEqual(NavigationSharing.parseText("51.5,-0.12 (Example Museum)"), .point(Coordinate(latitude: 51.5, longitude: -0.12), label: "Example Museum"))
        XCTAssertEqual(NavigationSharing.parseText("https://www.google.com/maps/search/?api=1&query=Example%20Museum"), .search("Example Museum"))
        XCTAssertEqual(NavigationSharing.parseText("https://www.google.com/maps/place/Example+Museum/"), .search("Example Museum"))
        XCTAssertEqual(NavigationSharing.parseText("Public + Museum"), .search("Public + Museum"))
        XCTAssertNil(NavigationSharing.parseText("https://www.google.com/maps/@51.5,-0.12,12z"))
        XCTAssertFalse(NavigationSharing.isDestinationInput("Example Museum"))
        XCTAssertTrue(NavigationSharing.isDestinationInput("51.5,-0.12"))
    }
    func testAmbiguousInvalidAndUntrustedLinksAreRejected() {
        for value in ["https://www.google.com/maps/?q=First&q=Second", "https://www.google.com/maps/?destination=First&q=Second", "https://evil.invalid/maps?q=Example", "https://www.google.com.evil.invalid/maps?q=Example", "https://user@www.google.com/maps?q=Example", "https://www.google.com:444/maps?q=Example", "http://www.google.com/maps?q=Example", "https://www.google.com/search?q=Example", "91,0", "51.5,invalid", "https://www.google.com/maps?q=place_id:123"] {
            XCTAssertNil(NavigationSharing.parseText(value), value)
        }
    }
    func testShortLinkIsNotFetchedUntilExplicitResolution() async throws {
        let short = URL(string: "https://maps.app.goo.gl/example")!
        XCTAssertEqual(NavigationSharing.parseText(short.absoluteString), .link(short))
        let result = try await NavigationSharing.resolve(short, headers: { url in
            XCTAssertEqual(url, short)
            return (302, "https://www.google.com/maps/?q=Example%20Museum")
        })
        XCTAssertEqual(result, .search("Example Museum"))
    }
    func testRedirectsCannotReachOtherHostsOrLoop() async throws {
        let short = URL(string: "https://maps.app.goo.gl/example")!
        let forbidden = try await NavigationSharing.resolve(short, headers: { _ in (302, "https://private.invalid/path") })
        XCTAssertNil(forbidden)
        let loop = try await NavigationSharing.resolve(short, headers: { _ in (302, short.absoluteString) })
        XCTAssertNil(loop)
        let relative = try await NavigationSharing.resolve(short, headers: { url in
            if url.path == "/example" { return (302, "/second") }
            return (302, "https://www.google.com/maps?q=Example")
        })
        XCTAssertEqual(relative, .search("Example"))
    }
    func testCancellationStopsResolutionAndOutboundModesRemainDistinct() async throws {
        let task = Task { try await NavigationSharing.resolve(URL(string: "https://maps.app.goo.gl/example")!, headers: { _ in try await Task.sleep(for: .seconds(60)); return (302, nil) }) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled resolution returned") } catch { XCTAssertTrue(error is CancellationError) }
        let place = Place(id: "public", name: "Example", address: "Example", coordinate: Coordinate(latitude: 51.5, longitude: 0))
        for (mode, expected) in [(TravelMode.car,"driving"), (.motorcycle,"driving"), (.bicycle,"bicycling"), (.walk,"walking")] {
            let parts = try XCTUnwrap(URLComponents(url: NavigationSharing.mapURL(for: place, mode: mode), resolvingAgainstBaseURL: false))
            XCTAssertEqual(parts.queryItems?.first(where: { $0.name == "travelmode" })?.value, expected)
        }
    }
}
