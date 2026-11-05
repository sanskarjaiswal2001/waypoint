import Combine
import CoreLocation
import FerrostarCore
import FerrostarCoreFFI
import WaypointKit

/// One location stream feeds both the phone UI and the navigation engine.
final class LocationSource: NSObject, LocationProviding, CLLocationManagerDelegate {
    weak var delegate: LocationManagingDelegate?
    @Published private(set) var fix: CLLocation?
    @Published private(set) var problem: String?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var headingDegrees: Double?
    @Published private(set) var headingSource: HeadingSource = .none
    private let manager = CLLocationManager()
    private var watchdog = LocationUpdateWatchdog()
    private var updating = false
    private var foreground = true
    private var headingArbiter = HeadingArbiter()
    var mode: TravelMode = .car { didSet { headingArbiter.reset(); refreshHeading() } }

    private let permissionHelp = "Enable location for Waypoint, or LiveContainer when hosted, in iOS Settings."

    var lastLocation: UserLocation? { fix?.userLocation }
    var lastHeading: Heading?

    var navigating = false {
        didSet {
            manager.allowsBackgroundLocationUpdates = navigating
            manager.showsBackgroundLocationIndicator = navigating
            if !navigating && !foreground { stopUpdating() }
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .otherNavigation
        authorizationStatus = manager.authorizationStatus
    }

    func request() {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            stopUpdating()
            startUpdating()
        case .denied, .restricted: problem = "Location access is disabled. " + permissionHelp
        @unknown default: problem = "Location is unavailable. Check Settings."
        }
    }

    func startUpdating() {
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }
        guard foreground || navigating else { return }
        problem = manager.accuracyAuthorization == .reducedAccuracy
            ? "Precise Location is off. " + permissionHelp : nil
        guard !updating else { return }
        updating = true
        watchdog.started()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stopUpdating() {
        updating = false
        watchdog.stopped()
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        headingArbiter.reset()
        refreshHeading()
    }

    func setForeground(_ foreground: Bool) {
        self.foreground = foreground
        if foreground { startUpdating() }
        else if !navigating { stopUpdating() }
    }

    func refreshIfNeeded() {
        refreshHeading()
        guard foreground || navigating else { return }
        guard watchdog.shouldRestart(fixTimestamp: fix?.timestamp) else { return }
        stopUpdating()
        startUpdating()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdating()
        case .denied, .restricted:
            fix = nil
            stopUpdating()
            problem = "Location access is disabled. " + permissionHelp
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard updating else { return }
        let fresh = locations.filter { candidate in
            candidate.horizontalAccuracy >= 0 && CLLocationCoordinate2DIsValid(candidate.coordinate)
                && LocationUpdateWatchdog.isFresh(candidate.timestamp)
                && (fix.map { candidate.timestamp > $0.timestamp } ?? true)
        }.sorted { $0.timestamp < $1.timestamp }
        guard let latest = fresh.last else { return }
        fix = latest
        headingArbiter.observeLocation(course: latest.course, speed: latest.speed,
            courseAccuracy: latest.courseAccuracy, speedAccuracy: latest.speedAccuracy,
            reliable: latest.horizontalAccuracy <= 60 && manager.accuracyAuthorization == .fullAccuracy,
            mode: mode, at: ProcessInfo.processInfo.systemUptime - max(0, Date().timeIntervalSince(latest.timestamp)))
        refreshHeading()
        problem = manager.accuracyAuthorization == .reducedAccuracy
            ? "Precise Location is off. " + permissionHelp
            : (latest.horizontalAccuracy > 65 ? "GPS accuracy is low. Waiting for a clearer position." : nil)
        delegate?.locationManager(self, didUpdateLocations: fresh.map(\.userLocation))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        headingArbiter.observeCompass(degrees, reliable: newHeading.headingAccuracy >= 0 && newHeading.headingAccuracy <= 45,
            at: ProcessInfo.processInfo.systemUptime - max(0, Date().timeIntervalSince(newHeading.timestamp)))
        refreshHeading()
        if headingDegrees != nil {
            lastHeading = Heading(clHeading: newHeading)
            if let lastHeading { delegate?.locationManager(self, didUpdateHeading: lastHeading) }
        } else { lastHeading = nil }
    }

    private func refreshHeading() {
        let reading = headingArbiter.current(at: ProcessInfo.processInfo.systemUptime)
        headingDegrees = reading.reliable ? reading.degrees : nil
        headingSource = reading.source
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard updating else { return }
        if (error as? CLError)?.code == .denied {
            stopUpdating()
            fix = nil
            problem = "Location is unavailable. " + permissionHelp
        } else {
            problem = "Waiting for GPS. Move to a clear view of the sky or tap Locate to retry."
        }
        delegate?.locationManager(self, didFailWithError: error)
    }
}
