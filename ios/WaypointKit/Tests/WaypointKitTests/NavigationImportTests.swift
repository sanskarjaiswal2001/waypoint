import XCTest
@testable import WaypointKit

final class NavigationImportTests: XCTestCase {
    func testGeoPointAndLabelPreserveCoordinateOrder() {
        XCTAssertEqual(NavigationImport.parse("geo:50,10"), .point(Coordinate(latitude: 50, longitude: 10), label: "Location at 50.00000, 10.00000"))
        XCTAssertEqual(NavigationImport.parse("geo:0,0?q=50.1%2C10.2%28Example%20Museum%29"), .point(Coordinate(latitude: 50.1, longitude: 10.2), label: "Example Museum"))
    }
    func testQueryIsDecodedOnceAfterSeparatingParameters() {
        XCTAssertEqual(NavigationImport.parse("google.navigation:q=Example+Museum%20%26%20Gallery&mode=w"), .search("Example Museum & Gallery"))
        XCTAssertEqual(NavigationImport.parse("geo:0,0?q=Example%2520Road"), .search("Example%20Road"))
    }
    func testUnsafeOrAmbiguousDestinationsAreRejected() {
        for value in ["https://example.com?q=Example", "geo://50,10", "geo:100,10", "geo:50,200", "geo:0,0?q=50,bad", "geo:0,0?q=first&q=second", "geo:0,0?q=%00Example", "google.navigation:q="] {
            XCTAssertNil(NavigationImport.parse(value), value)
        }
        XCTAssertNil(NavigationImport.parse("geo:0,0?q=" + String(repeating: "a", count: 300)))
    }
}
