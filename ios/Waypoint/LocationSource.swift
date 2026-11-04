import Combine
import CoreLocation
import FerrostarCore
import FerrostarCoreFFI

/// One location stream feeds both the phone UI and the navigation engine.
final class LocationSource: NSObject, LocationProviding, CLLocationManagerDelegate {
    weak var delegate: LocationManagingDelegate?
    @Published private(set) var fix: CLLocation?
    @Published private(set) var problem: String?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    var lastLocation: UserLocation? { fix?.userLocation }
    var lastHeading: Heading?

    var navigating = false {
        didSet {
            manager.allowsBackgroundLocationUpdates = navigating
            manager.pausesLocationUpdatesAutomatically = !navigating
            manager.showsBackgroundLocationIndicator = navigating
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.activityType = .otherNavigation
        authorizationStatus = manager.authorizationStatus
    }

    func request() {
        problem = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: startUpdating()
        case .denied, .restricted: problem = "Location access is disabled. Enable it for Waypoint in Settings."
        @unknown default: problem = "Location is unavailable. Check Settings."
        }
    }

    func startUpdating() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            problem = manager.accuracyAuthorization == .reducedAccuracy ? "Precise Location is off. Enable it in Settings before navigating." : nil
            startUpdating()
        case .denied, .restricted:
            fix = nil
            stopUpdating()
            problem = "Location access is disabled. Enable it for Waypoint in Settings."
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fresh = locations.filter { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 15 }
        guard let latest = fresh.last else { return }
        fix = latest
        problem = manager.accuracyAuthorization == .reducedAccuracy
            ? "Precise Location is off. Enable it in Settings before navigating."
            : (latest.horizontalAccuracy > 65 ? "GPS accuracy is low. Waiting for a clearer position." : nil)
        delegate?.locationManager(self, didUpdateLocations: fresh.map(\.userLocation))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = Heading(clHeading: newHeading)
        if let lastHeading { delegate?.locationManager(self, didUpdateHeading: lastHeading) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        problem = "GPS is unavailable. Move to a clear view of the sky and try Locate."
        delegate?.locationManager(self, didFailWithError: error)
    }
}
