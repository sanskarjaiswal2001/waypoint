import Foundation
import XCTest
@testable import WaypointKit

final class BundledGlyphStoreTests: XCTestCase {
    func testBundledGlyphIsDeliveredAsHTTP200WithOriginalBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("glyphs/Waypoint Classic", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = Data([0x0a, 0x02, 0x12, 0x00])
        try bytes.write(to: directory.appendingPathComponent("0-255.pbf"))
        let url = try XCTUnwrap(URL(string: "https://tiles.openfreemap.org/fonts/Waypoint%20Classic/0-255.pbf"))

        let resource = try XCTUnwrap(BundledGlyphStore(bundleURL: root).load(url))
        XCTAssertEqual(resource.data, bytes)
        // MapLibre rejects non-HTTP responses for HTTPS glyph requests.
        let response = try XCTUnwrap(resource.response as? HTTPURLResponse)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.url, url)
        XCTAssertEqual(response.mimeType, "application/x-protobuf")
        XCTAssertEqual(response.expectedContentLength, 4)
    }

    func testOnlyBundledFontRequestsAreIntercepted() throws {
        for url in ["https://tiles.openfreemap.org/planet",
                    "https://tiles.openfreemap.org/fonts/Noto%20Sans%20Regular/0-255.pbf",
                    "https://example.com/fonts/Waypoint%20Classic/0-255.pbf",
                    "https://tiles.openfreemap.org/fonts/Waypoint%20Classic/not-a-range.pbf"] {
            XCTAssertFalse(BundledGlyphStore.handles(try XCTUnwrap(URL(string: url))))
        }
        XCTAssertTrue(BundledGlyphStore.handles(try XCTUnwrap(URL(string:
            "https://tiles.openfreemap.org/fonts/Waypoint%20Classic/256-511.pbf"))))
    }

    func testMissingGlyphIsLeftForRemoteFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = try XCTUnwrap(URL(string: "https://tiles.openfreemap.org/fonts/Waypoint%20Classic/256-511.pbf"))
        XCTAssertNil(BundledGlyphStore(bundleURL: root).load(url))
    }
}
