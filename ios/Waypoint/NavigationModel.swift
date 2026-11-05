import Combine
import CoreLocation
import FerrostarCore
import FerrostarCoreFFI
import Observation
import SwiftUI
import WaypointKit

struct RoutingProvider: CustomRouteProvider {
    let mode: TravelMode
    var imperial = false
    var onFailure: (@Sendable () async -> Void)?

    func getRoutes(userLocation: UserLocation, waypoints: [Waypoint]) async throws -> [Route] {
        guard let destination = waypoints.last else { throw ServiceError.noRoute }
        let origin = userLocation.coordinates
        let data: Data
        do {
            data = try await MapService().routeData(
                from: Coordinate(latitude: origin.lat, longitude: origin.lng),
                to: Coordinate(latitude: destination.coordinate.lat, longitude: destination.coordinate.lng), mode: mode, imperial: imperial)
        } catch {
            if !Task.isCancelled { await onFailure?() }
            throw error
        }
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
        didSet { UserDefaults.standard.set(world.id, forKey: "world"); cameraRequest = UUID() }
    }
    var saved: [Place] {
        didSet { persist(saved, key: "saved") }
    }
    var recent: [Place] {
        didSet { persist(recent, key: "recent") }
    }
    var mode: TravelMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode"); location.mode = mode }
    }
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
    @ObservationIgnored private var followPolicy = MapFollowPolicy()
    private var tiltOverride = UserDefaults.standard.object(forKey: "tilted") as? Bool
    var tilted: Bool {
        get { tiltOverride ?? world.defaultTilted }
        set { tiltOverride = newValue; UserDefaults.standard.set(newValue, forKey: "tilted"); cameraRequest = UUID() }
    }
    var muted = false
    var mapError: String?
    var mapReloadRequest = UUID()
    var city = "Map preview"
    var pendingImport: NavigationImport?
    var questPlaceDraft: Place?
    let quests = QuestModel()
    var availableUpdate: IOSRelease?
    var updateStatus: String?
    var checkingUpdates = false
    @ObservationIgnored private var lastUpdateCheck: Date?
    var headingDegrees: Double?
    var imperial = UserDefaults.standard.bool(forKey: "imperial") {
        didSet { UserDefaults.standard.set(imperial, forKey: "imperial") }
    }
    var voiceEnabled = UserDefaults.standard.object(forKey: "voice") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(voiceEnabled, forKey: "voice")
            if navigating && muted == voiceEnabled { core?.spokenInstructionObserver.toggleMute(); muted = !voiceEnabled }
        }
    }
    var themedVoice = UserDefaults.standard.object(forKey: "themedVoice") as? Bool ?? true {
        didSet { UserDefaults.standard.set(themedVoice, forKey: "themedVoice") }
    }
    var favoriteWorlds = UserDefaults.standard.stringArray(forKey: "favoriteWorlds") ?? ["los_santos"] {
        didSet { UserDefaults.standard.set(favoriteWorlds, forKey: "favoriteWorlds") }
    }
    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private var geocodedLocation: CLLocation?
    @ObservationIgnored private var geocoding = false
    var showWelcome = !UserDefaults.standard.bool(forKey: "onboarded")

    @ObservationIgnored let location = LocationSource()
    @ObservationIgnored private var core: FerrostarCore?
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var coreSubscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var routingTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var searchService: PlaceSearch?

    static var releaseID: String {
        AppPreferences.releaseID(version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0",
                                 build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "6")
    }
    var releaseNotesPending = AppPreferences.shouldShowRelease(NavigationModel.releaseID, in: .standard)
    func markReleaseNotesSeen() {
        AppPreferences.markReleaseSeen(Self.releaseID, in: .standard)
        releaseNotesPending = false
    }

    func search(_ query: String, expanded: Bool = false) async throws -> PlaceSearchResult {
        if searchService == nil {
            let values = UserDefaults.standard.dictionary(forKey: "searchAliases") as? [String: String] ?? [:]
            searchService = PlaceSearch(primary: { try await MapService().search($0, near: $1) },
                fallback: { try await ApplePlaceSearch.find($0, near: $1) }, aliases: SearchAliases(values))
        }
        return try await searchService!.search(query, near: coordinate, local: saved + recent, expanded: expanded)
    }

    override init() {
        let defaults = UserDefaults.standard
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-waypoint-ui-testing") && !ProcessInfo.processInfo.arguments.contains("-waypoint-preserve-preferences") {
            for key in ["world", "onboarded", "saved", "recent", "mode", "releaseNotesSeen"] { defaults.removeObject(forKey: key) }
        }
        #endif
        world = World.all.first { $0.id == defaults.string(forKey: "world") } ?? World.all[0]
        saved = Self.restore("saved")
        recent = Self.restore("recent")
        mode = AppPreferences.travelMode(in: defaults)
        super.init()
        location.mode = mode
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-waypoint-ui-testing") && !ProcessInfo.processInfo.arguments.contains("-waypoint-preserve-preferences") {
            showWelcome = true
            releaseNotesPending = true
            favoriteWorlds = ["los_santos"]
            imperial = false
            voiceEnabled = true
            tiltOverride = nil
            defaults.removeObject(forKey: "tilted")
        }
        #endif
        location.$fix.receive(on: DispatchQueue.main).sink { [weak self] in
            if self?.fix == nil && $0 != nil { self?.cameraRequest = UUID() }
            self?.fix = $0
            self?.gpsStale = $0.map { !LocationUpdateWatchdog.isFresh($0.timestamp) } ?? false
            if let fix = $0 { self?.updateCity(fix) }
        }.store(in: &subscriptions)
        location.$headingDegrees.receive(on: DispatchQueue.main).sink { [weak self] in self?.headingDegrees = $0 }.store(in: &subscriptions)
        location.$problem.receive(on: DispatchQueue.main).sink { [weak self] problem in
            guard let self else { return }
            self.locationProblem = problem
            if self.location.authorizationStatus == .denied || self.location.authorizationStatus == .restricted {
                self.stop()
            }
        }.store(in: &subscriptions)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-waypoint-route-layout-fixture") {
            showWelcome = false
            releaseNotesPending = false
            select(Place(id: "layout-fixture", name: String(repeating: "Example public demonstration destination ", count: 5), address: String(repeating: "Example address for layout testing. ", count: 12), coordinate: Coordinate(latitude: 51.5, longitude: -0.12)))
        }
        #endif
    }

    var coordinate: Coordinate? {
        fix.map { Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }

    var hasFreshFix: Bool {
        guard let fix else { return false }
        return LocationUpdateWatchdog.isFresh(fix.timestamp) && (0...65).contains(fix.horizontalAccuracy) && locationProblem == nil
    }

    var bearing: Double? { headingDegrees }
    var fixLabel: String {
        if let fix, hasFreshFix { return "GPS ±\(Int(fix.horizontalAccuracy.rounded())) m · \(mode.title)" }
        return fix == nil ? "Map preview · \(mode.title)" : "Finding GPS · \(mode.title)"
    }
    var speedText: String {
        guard hasFreshFix, let fix, fix.speed >= 0 else { return "—" }
        return "\(Int((fix.speed * (imperial ? 2.23694 : 3.6)).rounded()))"
    }
    func distanceText(_ metres: Double) -> String {
        if imperial { return metres < 1609.344 ? "\(Int((metres * 3.28084).rounded())) ft" : String(format: "%.1f mi", metres / 1609.344) }
        return metres < 1000 ? "\(Int(metres.rounded())) m" : String(format: "%.1f km", metres / 1000)
    }
    func clearPlaces() { saved = []; recent = [] }
    func toggleFavorite(_ world: World) {
        if favoriteWorlds.contains(world.id) { favoriteWorlds.removeAll { $0 == world.id } }
        else { favoriteWorlds.append(world.id) }
    }
    private func updateCity(_ fix: CLLocation) {
        guard hasFreshFix, !geocoding, geocodedLocation.map({ fix.distance(from: $0) > 1000 && fix.timestamp.timeIntervalSince($0.timestamp) > 30 }) ?? true else { return }
        geocoding = true
        geocodedLocation = fix
        city = city == "Map preview" ? "Current location" : city
        geocoder.reverseGeocodeLocation(fix) { [weak self] places, _ in
            Task { @MainActor in
                self?.geocoding = false
                if let place = places?.first { self?.city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? "Current location" }
            }
        }
    }

    var duration: Double { navigation?.currentProgress?.durationRemaining ?? route?.steps.reduce(0) { $0 + $1.duration } ?? 0 }
    var distance: Double { navigation?.currentProgress?.distanceRemaining ?? route?.distance ?? 0 }
    var instruction: String {
        if navigation?.isCalculatingNewRoute == true { return "Finding a new route…" }
        if case .deviation = navigation?.currentDeviation { return "Checking your position for a new route" }
        return navigation?.currentVisualInstruction?.primaryContent.text
            ?? navigation?.currentStep?.instruction ?? "Follow the route"
    }

    func finishWelcome() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        showWelcome = false
    }

    func locate() {
        location.request()
        followPolicy.resume()
        followLocation = true
        cameraRequest = UUID()
    }

    func mapGestureStarted() {
        followPolicy.gestureStarted(at: ProcessInfo.processInfo.systemUptime)
        followLocation = false
    }
    func mapGestureEnded() { followPolicy.gestureEnded(at: ProcessInfo.processInfo.systemUptime) }
    func refreshFollow() {
        if followPolicy.shouldFollow(navigating: navigating, hasDestination: destination != nil, at: ProcessInfo.processInfo.systemUptime), !followLocation {
            followLocation = true
            cameraRequest = UUID()
        }
    }

    func retryMap() {
        mapError = nil
        mapReloadRequest = UUID()
    }

    func offerImport(_ value: String) {
        guard !navigating else { message = "End the current trip before opening another destination."; return }
        guard let proposal = NavigationImport.parse(value) else { message = "This destination link is invalid or unsupported."; return }
        pendingImport = proposal
    }

    func checkForUpdate(quiet: Bool = false) async {
        guard !checkingUpdates, !navigating else { return }
        if quiet && lastUpdateCheck.map({ Date().timeIntervalSince($0) < 86_400 }) == true { return }
        checkingUpdates = true
        defer { checkingUpdates = false }
        do {
            var request = URLRequest(url: ProjectLinks.releaseAPI, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Waypoint-iOS", forHTTPHeaderField: "User-Agent")
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200, response.expectedContentLength <= 2_000_000 else { throw ServiceError.invalidResponse }
            var data = Data()
            for try await byte in bytes { guard data.count < 2_000_000 else { throw ServiceError.tooLarge }; data.append(byte) }
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0"
            availableUpdate = try IOSRelease.newerRelease(in: data, currentVersion: version)
            lastUpdateCheck = Date()
            updateStatus = availableUpdate.map { "Version \($0.version) is available." } ?? "No newer upstream iOS preview found."
        } catch { if !quiet { updateStatus = "The update check failed. Try again later or open iOS releases." } }
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
        let provider = RoutingProvider(mode: mode, imperial: imperial, onFailure: { [weak self] in
            await self?.rerouteFailed(request: id)
        })
        let policy = GuidancePolicy(mode: mode)
        let config = SwiftNavigationControllerConfig(
            waypointAdvance: .waypointWithinRange(policy.waypointRadius),
            stepAdvanceCondition: stepAdvanceDistanceEntryAndExit(
                distanceToEndOfStep: 30, distanceAfterEndOfStep: 5, minimumHorizontalAccuracy: 32),
            arrivalStepAdvanceCondition: stepAdvanceDistanceToEndOfStep(distance: policy.arrivalDistance, minimumHorizontalAccuracy: 32),
            routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: policy.deviationAccuracy, maxAcceptableDeviation: policy.deviationDistance),
            snappedLocationCourseFiltering: .snapToRoute
        )
        let speaker = WorldSpeechSynthesizer { [weak self] in
            (self?.world ?? World.all[0], self?.navigation?.currentProgress?.distanceToNextManeuver ?? 0, self?.themedVoice ?? false)
        }
        let engine = FerrostarCore(routeProvider: .customProvider(provider), locationProvider: location,
                                  navigationControllerConfig: config, networkSession: URLSession.shared,
                                  spokenInstructionObserver: SpokenInstructionObserver(synthesizer: speaker, isMuted: !voiceEnabled))
        engine.minimumTimeBeforeRecalculation = GuidancePolicy.recalculationDelay
        engine.minimumMovementBeforeRecalculation = GuidancePolicy.recalculationMovement
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
            if core.spokenInstructionObserver.isMuted == voiceEnabled { core.spokenInstructionObserver.toggleMute() }
            muted = core.spokenInstructionObserver.isMuted
            try core.startNavigation(route: route)
            followPolicy.resume()
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
        followPolicy.resume()
        followLocation = true
        cameraRequest = UUID()
    }

    func toggleSaved(_ place: Place) {
        if saved.contains(where: { $0.id == place.id }) { saved.removeAll { $0.id == place.id } }
        else { saved = Array(([place] + saved).prefix(200)) }
    }
    func renameSaved(_ id: String, name: String) -> Bool {
        guard let index = saved.firstIndex(where: { $0.id == id }), let place = saved[index].renamed(name) else { return false }
        saved[index] = place
        if destination?.id == id { destination = place }
        recent = recent.map { $0.id == id ? place : $0 }
        return true
    }

    func toggleMute() {
        voiceEnabled.toggle()
    }

    func sceneChanged(_ phase: ScenePhase) {
        if phase == .background { location.setForeground(false) }
        if phase == .active { location.setForeground(true) }
    }

    func checkGPS() {
        gpsStale = fix.map { !LocationUpdateWatchdog.isFresh($0.timestamp) } ?? false
        location.refreshIfNeeded()
    }

    private func cancelRoute() {
        requestID = UUID()
        routingTask?.cancel()
        routingTask = nil
        routing = false
    }

    private func rerouteFailed(request: UUID) {
        guard requestID == request, navigating else { return }
        message = "Couldn't update the route. Keeping the current route; another attempt will follow as you move."
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
            do { try core.startNavigation(route: route); self.message = nil }
            catch { self.message = "Could not start the recalculated route. Stop and preview again when safe." }
        }
    }
}
