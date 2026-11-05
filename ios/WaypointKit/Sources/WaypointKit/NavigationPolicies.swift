import Foundation

public struct MapFollowPolicy {
    private var gestureAt: TimeInterval?
    private var gesturing = false
    public init() {}
    public mutating func gestureStarted(at now: TimeInterval) { gesturing = true; gestureAt = now }
    public mutating func gestureEnded(at now: TimeInterval) { if gesturing { gestureAt = now }; gesturing = false }
    public mutating func resume() { gestureAt = nil; gesturing = false }
    public mutating func shouldFollow(navigating: Bool, hasDestination: Bool, at now: TimeInterval) -> Bool {
        guard !gesturing else { return false }
        if let gestureAt, navigating, now - gestureAt >= 8 { resume() }
        return gestureAt == nil && (navigating || !hasDestination)
    }
}

public enum HeadingSource: String, Sendable { case none, compass, course }
public struct HeadingReading: Sendable {
    public let degrees: Double
    public let reliable: Bool
    public let source: HeadingSource
}

/// Times use a monotonic clock, so clock adjustments cannot prolong sensor freshness.
public struct HeadingArbiter {
    private var compass: Double?
    private var compassAt: TimeInterval?
    private var course: Double?
    private var courseAt: TimeInterval?
    private var courseActive = false
    private var last = 0.0
    public init() {}

    public mutating func observeCompass(_ degrees: Double, reliable: Bool, at now: TimeInterval) {
        compass = reliable && degrees.isFinite ? Self.normalized(degrees) : nil
        compassAt = now
    }
    public mutating func observeLocation(course bearing: Double, speed: Double, courseAccuracy: Double?, speedAccuracy: Double?, reliable: Bool, mode: TravelMode, at now: TimeInterval) {
        if !fresh(courseAt, at: now, age: 2.5) { courseActive = false }
        let enter = mode == .walk ? 1.1 : 2.5
        let exit = mode == .walk ? 0.65 : 1.5
        let goodCourse = courseAccuracy.map { $0.isFinite && (0...25).contains($0) } ?? true
        let goodSpeed = speedAccuracy.map { $0.isFinite && $0 >= 0 && speed - $0 > (mode == .walk ? 0.35 : 0.8) } ?? true
        courseActive = reliable && bearing.isFinite && bearing >= 0 && speed.isFinite && speed >= (courseActive ? exit : enter) && goodCourse && goodSpeed
        if courseActive { course = Self.normalized(bearing); courseAt = now }
    }
    public mutating func current(at now: TimeInterval) -> HeadingReading {
        if courseActive, let course, fresh(courseAt, at: now, age: 2.5) {
            last = course; return HeadingReading(degrees: last, reliable: true, source: .course)
        }
        if let compass, fresh(compassAt, at: now, age: 2) {
            last = compass; return HeadingReading(degrees: last, reliable: true, source: .compass)
        }
        return HeadingReading(degrees: last, reliable: false, source: .none)
    }
    public mutating func reset() { compass = nil; compassAt = nil; course = nil; courseAt = nil; courseActive = false }
    private func fresh(_ timestamp: TimeInterval?, at now: TimeInterval, age: TimeInterval) -> Bool {
        timestamp.map { (0...age).contains(now - $0) } ?? false
    }
    private static func normalized(_ value: Double) -> Double { (value.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
}

/// The thresholds used by Android's active Ferrostar guidance configuration.
public struct GuidancePolicy: Equatable, Sendable {
    public let waypointRadius: Double
    public let arrivalDistance: UInt16
    public let deviationAccuracy: UInt16
    public let deviationDistance: Double
    public static let recalculationDelay: TimeInterval = 5
    public static let recalculationMovement: Double = 50
    public init(mode: TravelMode) {
        waypointRadius = mode == .walk ? 25 : 45
        arrivalDistance = mode == .walk ? 15 : 25
        deviationAccuracy = mode == .walk ? 25 : 35
        deviationDistance = mode == .walk ? 25 : 50
    }
}

public enum AppPreferences {
    public static func travelMode(in defaults: UserDefaults) -> TravelMode {
        defaults.string(forKey: "mode").flatMap(TravelMode.init(rawValue:)) ?? .car
    }
    public static func releaseID(version: String, build: String) -> String { version + "." + build }
    public static func shouldShowRelease(_ release: String, in defaults: UserDefaults) -> Bool {
        defaults.string(forKey: "releaseNotesSeen") != release
    }
    public static func prepareReleaseNotice(_ release: String, existingInstall: Bool, in defaults: UserDefaults) -> Bool {
        if !existingInstall && defaults.object(forKey: "releaseNotesSeen") == nil { markReleaseSeen(release, in: defaults) }
        return shouldShowRelease(release, in: defaults)
    }
    public static func markReleaseSeen(_ release: String, in defaults: UserDefaults) { defaults.set(release, forKey: "releaseNotesSeen") }
}
