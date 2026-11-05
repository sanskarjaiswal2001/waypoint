import MapLibre
import FerrostarCore
import SwiftUI
import WaypointKit

struct WorldMap: UIViewRepresentable {
    let model: NavigationModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = try? model.world.styleURL()
        let map = MLNMapView(frame: .zero, styleURL: styleURL)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.delegate = context.coordinator
        context.coordinator.worldID = model.world.id
        context.coordinator.mapReloadRequest = model.mapReloadRequest
        if styleURL == nil { context.coordinator.report("The bundled map style could not load.") }
        map.setCenter(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12), zoomLevel: 10, animated: false)
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true
        map.compassView.isHidden = true
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dropPin(_:)))
        map.addGestureRecognizer(hold)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectPlace(_:)))
        tap.require(toFail: hold)
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panned(_:)))
        pan.delegate = context.coordinator
        map.addGestureRecognizer(pan)
        context.coordinator.map = map
        context.coordinator.watchLoading()
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        if coordinator.worldID != model.world.id {
            coordinator.worldID = model.world.id
            coordinator.ready = false
            coordinator.tilted = !model.tilted
            coordinator.watchLoading()
            do { map.styleURL = try model.world.styleURL() }
            catch { coordinator.report("The bundled map style could not load.") }
        }
        if coordinator.mapReloadRequest != model.mapReloadRequest {
            coordinator.mapReloadRequest = model.mapReloadRequest
            coordinator.ready = false
            coordinator.watchLoading()
            map.reloadStyle(nil)
        }
        map.showsUserLocation = false
        if coordinator.ready { coordinator.renderRoute() }
        if coordinator.cameraRequest != model.cameraRequest {
            coordinator.cameraRequest = model.cameraRequest
            coordinator.frameSelection()
        } else if model.followLocation, let location = model.navigation?.preferredUserLocation?.coordinates.clLocationCoordinate2D ?? model.fix?.coordinate {
            let camera = map.camera
            camera.centerCoordinate = location
            camera.pitch = model.tilted ? (model.navigating ? 50 : model.world.artTilt) : 0
            camera.heading = model.navigating ? (model.bearing ?? camera.heading) : camera.heading
            map.setCamera(camera, animated: true)
        }
        if coordinator.tilted != model.tilted {
            coordinator.tilted = model.tilted
            let camera = map.camera
            camera.pitch = model.tilted ? model.world.artTilt : 0
            map.setCamera(camera, animated: true)
        }
    }

    static func dismantleUIView(_ map: MLNMapView, coordinator: Coordinator) {
        coordinator.cancelLoadingWatch()
        map.delegate = nil
        map.showsUserLocation = false
    }

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        var model: NavigationModel
        weak var map: MLNMapView?
        var worldID: String?
        var ready = false
        var cameraRequest: UUID?
        var mapReloadRequest: UUID?
        var tilted = false
        private var renderedRoute: [CLLocationCoordinate2D] = []
        private var routeKey: Int?
        private var destinationID: String?
        private var loadingTimeout: DispatchWorkItem?
        private var renderedFrame = false

        init(model: NavigationModel) { self.model = model }

        func watchLoading() {
            cancelLoadingWatch()
            renderedFrame = false
            let timeout = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if !self.ready {
                    self.report("The map style has not finished loading. Retry the map.")
                } else if !self.renderedFrame {
                    self.report("The map style loaded, but rendering has not started. Retry the map.")
                } else {
                    self.report("The map style loaded, but some map resources are still pending. Retry the map.")
                }
            }
            loadingTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeout)
        }

        func cancelLoadingWatch() {
            loadingTimeout?.cancel()
            loadingTimeout = nil
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MapArtwork.install(model.world, in: style)
            for name in ["paper-fibre", "pixel-grass", "pixel-stone", "pixel-water"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "patterns"),
                   let image = UIImage(contentsOfFile: url.path) { style.setImage(image, forName: name) }
            }
            let source = MLNShapeSource(identifier: "ios-route", shape: nil, options: nil)
            style.addSource(source)
            let casing = MLNLineStyleLayer(identifier: "ios-route-casing", source: source)
            casing.lineColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.8))
            casing.lineWidth = NSExpression(forConstantValue: model.world.routeWidth + 3)
            casing.lineJoin = NSExpression(forConstantValue: "round")
            casing.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(casing)
            let line = MLNLineStyleLayer(identifier: "ios-route-line", source: source)
            line.lineColor = NSExpression(forConstantValue: model.world.routeColor)
            line.lineWidth = NSExpression(forConstantValue: model.world.routeWidth)
            line.lineJoin = NSExpression(forConstantValue: "round")
            line.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(line)
            for (name, icon, size) in [("ios-destination", "destination-marker", 0.45), ("ios-position", "nav-arrow", 0.32)] {
                let source = MLNShapeSource(identifier: name, shape: nil, options: nil)
                style.addSource(source)
                if name == "ios-position" {
                    let accuracy = MLNCircleStyleLayer(identifier: "ios-accuracy", source: source)
                    accuracy.circleColor = NSExpression(forConstantValue: UIColor(hex: "9CCBD8"))
                    accuracy.circleOpacity = NSExpression(forConstantValue: 0.10)
                    accuracy.circleStrokeColor = NSExpression(forConstantValue: UIColor(hex: "9CCBD8"))
                    accuracy.circleStrokeOpacity = NSExpression(forConstantValue: 0.4)
                    accuracy.circleStrokeWidth = NSExpression(forConstantValue: 1)
                    style.addLayer(accuracy)
                }
                let layer = MLNSymbolStyleLayer(identifier: name, source: source)
                layer.iconImageName = NSExpression(forConstantValue: icon)
                layer.iconScale = NSExpression(forConstantValue: size)
                layer.iconAllowsOverlap = NSExpression(forConstantValue: true)
                layer.iconIgnoresPlacement = NSExpression(forConstantValue: true)
                layer.iconRotationAlignment = NSExpression(forConstantValue: "map")
                style.addLayer(layer)
            }
            ready = true
            routeKey = nil
            destinationID = nil
            renderRoute()
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            cancelLoadingWatch()
            DispatchQueue.main.async { self.model.mapError = nil }
        }

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            cancelLoadingWatch()
            report(error.localizedDescription)
        }

        func mapViewDidFinishRenderingFrame(_ mapView: MLNMapView, fullyRendered: Bool) {
            renderedFrame = true
        }

        func report(_ message: String) {
            DispatchQueue.main.async { self.model.mapError = message }
        }

        func renderRoute() {
            guard let map, let style = map.style else { return }
            let dotted = (model.world.id == "night_city" && model.mode == .walk) || (model.world.id == "saints" && model.navigating)
            let line = style.layer(withIdentifier: "ios-route-line") as? MLNLineStyleLayer
            line?.lineColor = NSExpression(forConstantValue: model.world.id == "saints" && model.navigating ? UIColor(hex: "86D955") : model.world.routeColor)
            line?.lineDashPattern = NSExpression(forConstantValue: dotted ? [0.3, 1.8] : [1.0, 0.0])
            var opacity = model.navigation?.isCalculatingNewRoute == true ? 0.45 : 1.0
            if case .deviation = model.navigation?.currentDeviation { opacity = 0.45 }
            line?.lineOpacity = NSExpression(forConstantValue: opacity)
            (style.layer(withIdentifier: "ios-route-casing") as? MLNLineStyleLayer)?.lineOpacity = NSExpression(forConstantValue: dotted ? 0 : opacity)
            var hasher = Hasher()
            hasher.combine(model.route)
            hasher.combine(model.navigation?.tripState)
            let key = hasher.finalize()
            if routeKey != key {
                routeKey = key
                if let state = model.navigation, case let .navigating(index, _, snapped, steps, _, _, _, _, _, _, _) = state.tripState,
                   let first = steps.first {
                    let start = Int(min(UInt64(first.geometry.count), index ?? 0))
                    renderedRoute = [snapped.coordinates.clLocationCoordinate2D]
                        + first.geometry.dropFirst(start).map(\.clLocationCoordinate2D)
                        + steps.dropFirst().flatMap { $0.geometry.map(\.clLocationCoordinate2D) }
                } else { renderedRoute = model.route?.geometry.map(\.clLocationCoordinate2D) ?? [] }
                let shape: MLNPolylineFeature? = renderedRoute.count > 1
                    ? MLNPolylineFeature(coordinates: &renderedRoute, count: UInt(renderedRoute.count)) : nil
                (style.source(withIdentifier: "ios-route") as? MLNShapeSource)?.shape = shape
            }
            if destinationID != model.destination?.id {
                destinationID = model.destination?.id
                if let place = model.destination {
                    let point = MLNPointFeature()
                    point.coordinate = CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                    (style.source(withIdentifier: "ios-destination") as? MLNShapeSource)?.shape = point
                } else { (style.source(withIdentifier: "ios-destination") as? MLNShapeSource)?.shape = nil }
            }
            if let fix = model.fix {
                let point = MLNPointFeature()
                point.coordinate = model.navigation?.preferredUserLocation?.coordinates.clLocationCoordinate2D ?? fix.coordinate
                (style.source(withIdentifier: "ios-position") as? MLNShapeSource)?.shape = point
                let metresPerPoint = map.metersPerPoint(atLatitude: fix.coordinate.latitude)
                let radius = fix.horizontalAccuracy.isFinite && fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy < 5000 && metresPerPoint > 0
                    ? fix.horizontalAccuracy / metresPerPoint : 0
                (style.layer(withIdentifier: "ios-accuracy") as? MLNCircleStyleLayer)?.circleRadius = NSExpression(forConstantValue: radius)
                if let layer = style.layer(withIdentifier: "ios-position") as? MLNSymbolStyleLayer {
                    let known = model.hasFreshFix && model.bearing != nil
                    layer.iconImageName = NSExpression(forConstantValue: known ? "nav-arrow" : "position-uncertain")
                    layer.iconRotation = NSExpression(forConstantValue: known ? (model.bearing ?? 0) : 0)
                }
            } else { (style.source(withIdentifier: "ios-position") as? MLNShapeSource)?.shape = nil }
        }

        func frameSelection() {
            guard let map else { return }
            if !model.followLocation, let route = model.route, route.geometry.count > 1 {
                var coordinates = route.geometry.map(\.clLocationCoordinate2D)
                let landscape = map.bounds.width > map.bounds.height
                let insets = landscape
                    ? UIEdgeInsets(top: min(130, map.bounds.height * 0.35), left: 24, bottom: 40, right: min(370, map.bounds.width * 0.46))
                    : UIEdgeInsets(top: min(150, map.bounds.height * 0.2), left: 30, bottom: min(330, map.bounds.height * 0.45), right: 30)
                map.setVisibleCoordinates(&coordinates, count: UInt(coordinates.count),
                                          edgePadding: insets, animated: true)
            } else if !model.followLocation, let place = model.destination {
                map.setCenter(CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
                              zoomLevel: 15, animated: true)
            } else if let fix = model.fix {
                map.setCenter(fix.coordinate, zoomLevel: model.navigating ? 17 : model.world.artZoom, animated: true)
            }
        }

        @objc func dropPin(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, !model.navigating, let map else { return }
            let coordinate = map.convert(recognizer.location(in: map), toCoordinateFrom: map)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            model.select(Place(id: "pin:\(UUID().uuidString)", name: "Dropped pin", address: String(format: "%.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), coordinate.latitude, coordinate.longitude),
                               coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)))
        }

        @objc func selectPlace(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, !model.navigating, let map else { return }
            let layers = Set(["essential","utility","discovery","community","support","social","other"].map { "waypoint-\($0)-places" })
            let features = map.visibleFeatures(at: recognizer.location(in: map), styleLayerIdentifiers: layers)
            for feature in features {
                guard let point = feature as? MLNPointFeature else { continue }
                let raw = feature.attributes["name:en"] as? String ?? feature.attributes["name_en"] as? String ?? feature.attributes["name"] as? String
                guard let raw else { continue }
                let name = String(raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, CLLocationCoordinate2DIsValid(point.coordinate) else { continue }
                model.select(Place(id: "map:\(UUID().uuidString)", name: name, address: "Selected on map", coordinate: Coordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)))
                return
            }
        }

        @objc func panned(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began: model.mapGestureStarted()
            case .ended, .cancelled, .failed: model.mapGestureEnded()
            default: break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
