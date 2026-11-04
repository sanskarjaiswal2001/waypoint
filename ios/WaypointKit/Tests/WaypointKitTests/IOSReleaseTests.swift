import Foundation
import XCTest
@testable import WaypointKit

final class IOSReleaseTests: XCTestCase {
    private func data(_ rows: [[String: Any]]) throws -> Data { try JSONSerialization.data(withJSONObject: rows) }
    private func release(_ tag: String, draft: Bool = false, url: String? = nil) -> [String: Any] {
        ["tag_name":tag, "draft":draft, "html_url":url ?? "https://github.com/sanskarjaiswal2001/waypoint/releases/tag/\(tag)"]
    }
    func testSelectsNewestIOSPreviewAndIgnoresAndroidAndDrafts() throws {
        let response = try data([release("v9.0.0"), release("ios-v0.1.3"), release("ios-v0.2.0"), release("ios-v0.3.0", draft: true)])
        XCTAssertEqual(try IOSRelease.newerRelease(in: response, currentVersion: "0.1.3")?.version, "0.2.0")
    }
    func testEqualAndOlderVersionsDoNotTriggerUpdates() throws {
        XCTAssertNil(try IOSRelease.newerRelease(in: data([release("ios-v0.1.3")]), currentVersion: "0.2.0"))
        XCTAssertNil(try IOSRelease.newerRelease(in: data([release("ios-v0.2.0")]), currentVersion: "0.2.0"))
    }
    func testReleaseLinksAreRestrictedToThisFork() throws {
        for url in ["http://github.com/sanskarjaiswal2001/waypoint/releases/tag/ios-v0.3.0", "https://github.com.evil.invalid/sanskarjaiswal2001/waypoint/releases/tag/ios-v0.3.0", "https://github.com/other/project/releases/tag/ios-v0.3.0"] {
            XCTAssertNil(try IOSRelease.newerRelease(in: data([release("ios-v0.3.0", url: url)]), currentVersion: "0.2.0"))
        }
    }
}
