import Foundation
import XCTest
@testable import WaypointKit

final class LocationUpdateWatchdogTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testStaleStationaryFixTriggersRecovery() {
        var watchdog = LocationUpdateWatchdog()
        watchdog.started(at: start)
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: start, at: start.addingTimeInterval(14)))
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: start, at: start.addingTimeInterval(15)))
        XCTAssertTrue(watchdog.shouldRestart(fixTimestamp: start, at: start.addingTimeInterval(30)))
        XCTAssertFalse(LocationUpdateWatchdog.isFresh(start, at: start.addingTimeInterval(15)))
    }

    func testNoInitialFixIsRetriedAndAttemptsAreThrottled() {
        var watchdog = LocationUpdateWatchdog()
        watchdog.started(at: start)
        XCTAssertTrue(watchdog.shouldRestart(fixTimestamp: nil, at: start.addingTimeInterval(30)))
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: nil, at: start.addingTimeInterval(35)))
        XCTAssertTrue(watchdog.shouldRestart(fixTimestamp: nil, at: start.addingTimeInterval(60)))
    }

    func testRecentFixPreventsUnnecessaryRestarts() {
        var watchdog = LocationUpdateWatchdog()
        watchdog.started(at: start)
        let now = start.addingTimeInterval(60)
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: now.addingTimeInterval(-2), at: now))
        XCTAssertTrue(watchdog.shouldRestart(fixTimestamp: now.addingTimeInterval(-2), at: now.addingTimeInterval(15)))
    }

    func testStoppedStreamDoesNotRestartInBackgroundOrAfterDenial() {
        var watchdog = LocationUpdateWatchdog()
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: nil, at: start))
        watchdog.started(at: start)
        watchdog.stopped()
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: start, at: start.addingTimeInterval(60)))
    }

    func testResumeWithoutInitialFixAllowsTimeToAcquireGPS() {
        var watchdog = LocationUpdateWatchdog()
        watchdog.started(at: start)
        watchdog.stopped()
        let resumed = start.addingTimeInterval(60)
        watchdog.started(at: resumed)
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: nil, at: resumed))
        XCTAssertFalse(watchdog.shouldRestart(fixTimestamp: nil, at: resumed.addingTimeInterval(15)))
        XCTAssertTrue(watchdog.shouldRestart(fixTimestamp: nil, at: resumed.addingTimeInterval(30)))
    }

    func testCachedAndFutureDatedFixesAreNotFresh() {
        XCTAssertTrue(LocationUpdateWatchdog.isFresh(start, at: start.addingTimeInterval(1)))
        XCTAssertFalse(LocationUpdateWatchdog.isFresh(start, at: start.addingTimeInterval(15)))
        XCTAssertFalse(LocationUpdateWatchdog.isFresh(start.addingTimeInterval(60), at: start))
    }
}
