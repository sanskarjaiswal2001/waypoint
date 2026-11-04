import Combine
import CoreLocation
import FerrostarCore
import FerrostarCoreFFI
import Observation
import SwiftUI
import WaypointKit

struct RoutingProvider: CustomRouteProvider {
    let mode: TravelMode

    func getRoutes(userLocation: UserLocation, waypoints: [Waypoint]) async throws -> [Route] {
        guard let destination = waypoints.last else { throw ServiceError.noRoute }
        let origin = userLocation.coordinates
        let data = try await MapService().routeData(
            from: Coordinate(latitude: origin.lat, longitude: origin.lng),
            to: Coordinate(latitude: destination.coordinate.lat, longitude: destination.coordinate.lng), mode: mode
        )
        try Task.checkCancellation()
        let route = try createRouteFromOsrmRoute(routeData: data, waypoints: [
            Waypoint(coordinate: origin, kind: .break), destination
        ], polylinePrecision: 6)
        return [route]
    }
}

@MainActor @Observable
final class NavigationModel: NSObject {
    var world: World {
        didSet { UserDefaults.standard.set(world.id, forKey: "world") }
    }
    var saved: [Place] {
        didSet { persist(saved, key: "saved") }
    }
    var recent: [Place] {
        didSet { persist(recent, key: "recent") }
    }
    var mode: TravelMode = .car
    var destination: Place?
    var route: Route?
    var navigation: NavigationState?
    var navigating = false
    var routing = false
    var message: String?
    var fix: CLLocation?
    var locationProblem: String?
    var gpsStale = false
    var cameraRequest = UUID()
    var followLocation = true
    var tilted = false
    var muted = false
    var mapError: String?
    var showWelcome = !UserDefaults.standard.bool(forKey: "onboarded")

    @ObservationIgnored let location = LocationSource()
    @ObservationIgnored private var core: FerrostarCore?
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var coreSubscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var routingTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    override init() {
        let defaults = UserDefaults.standard
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-waypoint-ui-testing") {
            for key in ["world", "onboarded", "saved", "recent"] { defaults.removeObject(forKey: key) }
        }
        #endif
        world = World.all.first { $0.id == defaults.string(forKey: "world") } ?? World.all[0]
        saved = Self.restore("saved")
        recent = Self.restore("recent")
        super.init()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-waypoint-ui-testing") { showWelcome = true }
        #endif
        location.$fix.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.fix = $0
            self?.gpsStale = false
        }.store(in: &subscriptions)
        location.$problem.receive(on: DispatchQueue.main).sink { [weak self] problem in
            guard let self else { return }
            self.locationProblem = problem
            if self.location.authorizationStatus == .denied || self.location.authorizationStatus == .restricted {
                self.stop()
            }
        }.store(in: &subscriptions)
    }

    var coordinate: Coordinate? {
        fix.map { Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }

    var hasFreshFix: Bool {
        guard let fix else { return false }
        return abs(fix.timestamp.timeIntervalSinceNow) < 15 && (0...65).contains(fix.horizontalAccuracy) && locationProblem == nil
    }

    var duration: Double { navigation?.currentProgress?.durationRemaining ?? route?.steps.reduce(0) { $0 + $1.duration } ?? 0 }
    var distance: Double { navigation?.currentProgress?.distanceRemaining ?? route?.distance ?? 0 }
    var instruction: String {
        if navigation?.isCalculatingNewRoute == true { return "Finding a new route…" }
        return navigation?.currentVisualInstruction?.primaryContent.text
            ?? navigation?.currentStep?.instruction ?? "Follow the route"
    }

    func finishWelcome() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        showWelcome = false
    }

    func locate() {
        location.request()
        followLocation = true
        cameraRequest = UUID()
    }

    func select(_ place: Place) {
        guard !navigating else { return }
        cancelRoute()
        destination = place
        route = nil
        message = nil
        followLocation = false
        cameraRequest = UUID()
    }

    func changeMode(_ mode: TravelMode) {
        guard !navigating else { return }
        self.mode = mode
        cancelRoute()
        route = nil
    }

    func preview() {
        guard let destination else { return }
        guard hasFreshFix, let userLocation = location.lastLocation else {
            locate()
            message = "Waiting for a precise GPS position. Tap Preview route again when Locate has found you."
            return
        }
        cancelRoute()
        route = nil
        routing = true
        message = nil
        let id = UUID()
        requestID = id
        let provider = RoutingProvider(mode: mode)
        let config = SwiftNavigationControllerConfig(
            waypointAdvance: .waypointWithinRange(25),
            stepAdvanceCondition: stepAdvanceDistanceEntryAndExit(
                distanceToEndOfStep: 30, distanceAfterEndOfStep: 5, minimumHorizontalAccuracy: 32),
            arrivalStepAdvanceCondition: stepAdvanceDistanceToEndOfStep(distance: 10, minimumHorizontalAccuracy: 32),
            routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: 15, maxAcceptableDeviation: 50),
            snappedLocationCourseFiltering: .snapToRoute
        )
        let engine = FerrostarCore(routeProvider: .customProvider(provider), locationProvider: location,
                                  navigationControllerConfig: config, networkSession: URLSession.shared)
        engine.minimumTimeBeforeRecalculation = 10
        engine.delegate = self
        core = engine
        coreSubscriptions.removeAll()
        engine.$state.receive(on: DispatchQueue.main).sink { [weak self] state in
            guard let self, self.navigating else { return }
            self.navigation = state
            if case .complete = state?.tripState {
                self.stop()
                self.message = "You have arrived at your destination."
            }
        }.store(in: &coreSubscriptions)
        engine.$route.receive(on: DispatchQueue.main).sink { [weak self] route in
            if let route { self?.route = route }
        }.store(in: &coreSubscriptions)
        routingTask = Task { [weak self] in
            do {
                let routes = try await engine.getRoutes(initialLocation: userLocation, waypoints: [
                    Waypoint(coordinate: GeographicCoordinate(lat: destination.coordinate.latitude,
                                                              lng: destination.coordinate.longitude), kind: .break)
                ])
                try Task.checkCancellation()
                guard let self, self.requestID == id, let route = routes.first else { return }
                self.route = route
                self.routing = false
                self.followLocation = false
                self.cameraRequest = UUID()
            } catch {
                guard let self, self.requestID == id, !Task.isCancelled else { return }
                self.routing = false
                self.message = error.localizedDescription
            }
        }
    }

    func start() {
        guard let route, let core, hasFreshFix else {
            message = "Wait for a precise GPS position before starting navigation."
            return
        }
        do {
            location.navigating = true
            navigating = true
            try core.startNavigation(route: route)
            followLocation = true
            cameraRequest = UUID()
            UIApplication.shared.isIdleTimerDisabled = true
            if let destination {
                recent = Array(([destination] + recent.filter { $0.id != destination.id }).prefix(20))
            }
        } catch {
            navigating = false
            location.navigating = false
            message = "Navigation could not start. Preview the route and try again."
        }
    }

    func stop() {
        cancelRoute()
        navigating = false
        coreSubscriptions.removeAll()
        core?.stopNavigation()
        core = nil
        location.navigating = false
        navigation = nil
        route = nil
        muted = false
        UIApplication.shared.isIdleTimerDisabled = false
        location.startUpdating()
    }

    func clearDestination() {
        stop()
        destination = nil
    }

    func toggleSaved(_ place: Place) {
        if saved.contains(where: { $0.id == place.id }) { saved.removeAll { $0.id == place.id } }
        else { saved = Array(([place] + saved).prefix(200)) }
    }

    func toggleMute() {
        core?.spokenInstructionObserver.toggleMute()
        muted = core?.spokenInstructionObserver.isMuted ?? false
    }

    func sceneChanged(_ phase: ScenePhase) {
        if phase == .background && !navigating { location.stopUpdating() }
        if phase == .active && fix != nil { location.startUpdating() }
    }

    func checkGPS() {
        gpsStale = fix.map { abs($0.timestamp.timeIntervalSinceNow) >= 15 } ?? false
    }

    private func cancelRoute() {
        requestID = UUID()
        routingTask?.cancel()
        routingTask = nil
        routing = false
    }

    private func persist(_ places: [Place], key: String) {
        if let data = try? JSONEncoder().encode(places) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func restore(_ key: String) -> [Place] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let places = try? JSONDecoder().decode([Place].self, from: data) else { return [] }
        return places.filter { $0.coordinate.isValid }
    }
}

extension NavigationModel: FerrostarCoreDelegate {
    nonisolated func core(_ core: FerrostarCore, didStartWith route: Route) {}

    nonisolated func core(_ core: FerrostarCore, correctiveActionForDeviation deviation: DeviationKind,
              remainingWaypoints waypoints: [Waypoint]) -> CorrectiveAction {
        // Ferrostar 0.59 invokes synchronous deviation decisions on the main queue.
        MainActor.assumeIsolated {
            self.core === core && navigating && hasFreshFix ? .getNewRoutes(waypoints: waypoints) : .doNothing
        }
    }

    nonisolated func core(_ core: FerrostarCore, loadedAlternateRoutes routes: [Route]) {
        Task { @MainActor [weak self] in
            guard let self, self.core === core, self.navigating, let route = routes.first else { return }
            do { try core.startNavigation(route: route) }
            catch { self.message = "Could not start the recalculated route. Stop and preview again when safe." }
        }
    }
}
