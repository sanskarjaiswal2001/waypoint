import Foundation
import XCTest
@testable import WaypointKit

final class NavigationPoliciesTests: XCTestCase {
    func testFollowResumesEightSecondsAfterGestureEnds() {
        var policy = MapFollowPolicy()
        policy.gestureStarted(at: 0)
        XCTAssertFalse(policy.shouldFollow(navigating: true, hasDestination: true, at: 30))
        policy.gestureEnded(at: 30)
        XCTAssertFalse(policy.shouldFollow(navigating: true, hasDestination: true, at: 37.9))
        XCTAssertTrue(policy.shouldFollow(navigating: true, hasDestination: true, at: 38))
    }
    func testPreviewStaysStillAndLocateResumesImmediately() {
        var policy = MapFollowPolicy()
        XCTAssertFalse(policy.shouldFollow(navigating: false, hasDestination: true, at: 0))
        policy.gestureStarted(at: 1); policy.gestureEnded(at: 2)
        XCTAssertFalse(policy.shouldFollow(navigating: false, hasDestination: false, at: 100))
        policy.resume()
        XCTAssertTrue(policy.shouldFollow(navigating: false, hasDestination: false, at: 100))
    }
    func testStationaryNoisyAndInaccurateCourseCannotOverrideCompass() {
        var arbiter = HeadingArbiter()
        arbiter.observeCompass(40, reliable: true, at: 0)
        for (speed, courseAccuracy, speedAccuracy, reliable) in [(0.0, 5.0, 0.2, true), (4, 60, 0.2, true), (4, 10, 4, true), (4, 10, 0.2, false)] {
            arbiter.observeLocation(course: 90, speed: speed, courseAccuracy: courseAccuracy, speedAccuracy: speedAccuracy, reliable: reliable, mode: .car, at: 0.1)
            XCTAssertEqual(arbiter.current(at: 0.1).source, .compass)
        }
    }
    func testWalkingThresholdAndDrivingHysteresis() {
        var arbiter = HeadingArbiter()
        arbiter.observeLocation(course: 90, speed: 1.4, courseAccuracy: 12, speedAccuracy: 0.2, reliable: true, mode: .walk, at: 0)
        XCTAssertEqual(arbiter.current(at: 0).source, .course)
        arbiter.reset()
        arbiter.observeLocation(course: 80, speed: 3, courseAccuracy: 8, speedAccuracy: 0.2, reliable: true, mode: .car, at: 0)
        arbiter.observeLocation(course: 82, speed: 2, courseAccuracy: 8, speedAccuracy: 0.2, reliable: true, mode: .car, at: 0.5)
        XCTAssertEqual(arbiter.current(at: 0.5).source, .course)
        arbiter.observeCompass(40, reliable: true, at: 0.5)
        arbiter.observeLocation(course: 84, speed: 0.3, courseAccuracy: 8, speedAccuracy: 0.2, reliable: true, mode: .car, at: 0.6)
        XCTAssertEqual(arbiter.current(at: 0.6).source, .compass)
    }
    func testFreshCourseWinsButExpiresAndMustReenterAtHigherSpeed() {
        var arbiter = HeadingArbiter()
        arbiter.observeLocation(course: 80, speed: 3, courseAccuracy: 8, speedAccuracy: 0.2, reliable: true, mode: .car, at: 0)
        arbiter.observeCompass(240, reliable: true, at: 1)
        XCTAssertEqual(arbiter.current(at: 1).degrees, 80)
        arbiter.observeCompass(40, reliable: true, at: 3)
        XCTAssertEqual(arbiter.current(at: 3).source, .compass)
        arbiter.observeLocation(course: 82, speed: 2, courseAccuracy: 8, speedAccuracy: 0.2, reliable: true, mode: .car, at: 3.1)
        XCTAssertEqual(arbiter.current(at: 3.1).source, .compass)
        XCTAssertFalse(arbiter.current(at: 6).reliable)
    }
    func testInvalidFutureAndUnreliableSensorsHaveNoDirection() {
        var arbiter = HeadingArbiter()
        arbiter.observeCompass(.nan, reliable: true, at: 0)
        XCTAssertFalse(arbiter.current(at: 0).reliable)
        arbiter.observeCompass(40, reliable: false, at: 0)
        XCTAssertFalse(arbiter.current(at: 0).reliable)
        arbiter.observeCompass(40, reliable: true, at: 2)
        XCTAssertFalse(arbiter.current(at: 1).reliable)
        arbiter.reset()
        XCTAssertEqual(arbiter.current(at: 2).source, .none)
    }
    func testGuidanceThresholdsMatchActiveAndroidConfiguration() {
        let walk = GuidancePolicy(mode: .walk)
        XCTAssertEqual(walk.waypointRadius, 25); XCTAssertEqual(walk.arrivalDistance, 15)
        XCTAssertEqual(walk.deviationAccuracy, 25); XCTAssertEqual(walk.deviationDistance, 25)
        for mode in [TravelMode.car, .motorcycle] {
            let policy = GuidancePolicy(mode: mode)
            XCTAssertEqual(policy.waypointRadius, 45); XCTAssertEqual(policy.arrivalDistance, 25)
            XCTAssertEqual(policy.deviationAccuracy, 35); XCTAssertEqual(policy.deviationDistance, 50)
        }
        XCTAssertEqual(GuidancePolicy.recalculationDelay, 5); XCTAssertEqual(GuidancePolicy.recalculationMovement, 50)
    }
    func testTravelModeSurvivesRestorationAndUnknownValueUsesCar() throws {
        let name = "WaypointTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(AppPreferences.travelMode(in: defaults), .car)
        defaults.set("walk", forKey: "mode")
        XCTAssertEqual(AppPreferences.travelMode(in: try XCTUnwrap(UserDefaults(suiteName: name))), .walk)
        defaults.set("unknown", forKey: "mode")
        XCTAssertEqual(AppPreferences.travelMode(in: defaults), .car)
    }
    func testReleaseNotesAppearOncePerBuildAndCanBeDeferred() throws {
        let name = "WaypointTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let release = AppPreferences.releaseID(version: "0.3.0", build: "6")
        XCTAssertTrue(AppPreferences.shouldShowRelease(release, in: defaults))
        XCTAssertTrue(AppPreferences.shouldShowRelease(release, in: defaults))
        AppPreferences.markReleaseSeen(release, in: defaults)
        XCTAssertFalse(AppPreferences.shouldShowRelease(release, in: defaults))
        XCTAssertTrue(AppPreferences.shouldShowRelease(AppPreferences.releaseID(version: "0.3.0", build: "7"), in: defaults))
    }
    func testFreshInstallSkipsNotesWhileAnUpgradeKeepsThemPending() throws {
        let name = "WaypointTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertFalse(AppPreferences.prepareReleaseNotice("0.3.0.6", existingInstall: false, in: defaults))
        defaults.set("0.2.0.5", forKey: "releaseNotesSeen")
        XCTAssertTrue(AppPreferences.prepareReleaseNotice("0.3.0.6", existingInstall: true, in: defaults))
        XCTAssertEqual(defaults.string(forKey: "releaseNotesSeen"), "0.2.0.5")
    }
}
