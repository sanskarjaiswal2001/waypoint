import MapLibre
import SwiftUI
import WaypointKit

struct WorldMap: UIViewRepresentable {
    let model: NavigationModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero)
        map.delegate = context.coordinator
        map.setCenter(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12), zoomLevel: 10, animated: false)
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true
        map.compassView.isHidden = false
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dropPin(_:)))
        map.addGestureRecognizer(hold)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panned(_:)))
        pan.delegate = context.coordinator
        map.addGestureRecognizer(pan)
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        if coordinator.worldID != model.world.id {
            coordinator.worldID = model.world.id
            coordinator.ready = false
            do { map.styleJSON = try model.world.styleJSON() }
            catch { coordinator.report("The bundled map style could not load.") }
        }
        map.showsUserLocation = model.fix != nil
        if coordinator.ready { coordinator.renderRoute() }
        if coordinator.cameraRequest != model.cameraRequest {
            coordinator.cameraRequest = model.cameraRequest
            coordinator.frameSelection()
        } else if model.followLocation, let location = model.navigation?.preferredUserLocation?.coordinates.clLocationCoordinate2D ?? model.fix?.coordinate {
            let camera = map.camera
            camera.centerCoordinate = location
            camera.pitch = model.tilted ? 50 : 0
            camera.heading = model.navigating ? max(0, model.fix?.course ?? 0) : 0
            map.setCamera(camera, animated: true)
        }
        if coordinator.tilted != model.tilted {
            coordinator.tilted = model.tilted
            let camera = map.camera
            camera.pitch = model.tilted ? 50 : 0
            map.setCamera(camera, animated: true)
        }
    }

    static func dismantleUIView(_ map: MLNMapView, coordinator: Coordinator) {
        map.delegate = nil
        map.showsUserLocation = false
    }

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        var model: NavigationModel
        weak var map: MLNMapView?
        var worldID: String?
        var ready = false
        var cameraRequest: UUID?
        var tilted = false
        private var renderedRoute: [CLLocationCoordinate2D] = []
        private var routeKey: Int?
        private var destinationID: String?

        init(model: NavigationModel) { self.model = model }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            for name in ["paper-fibre", "pixel-grass", "pixel-stone", "pixel-water"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "patterns"),
                   let image = UIImage(contentsOfFile: url.path) { style.setImage(image, forName: name) }
            }
            let source = MLNShapeSource(identifier: "ios-route", shape: nil, options: nil)
            style.addSource(source)
            let casing = MLNLineStyleLayer(identifier: "ios-route-casing", source: source)
            casing.lineColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.8))
            casing.lineWidth = NSExpression(forConstantValue: 8)
            casing.lineJoin = NSExpression(forConstantValue: "round")
            casing.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(casing)
            let line = MLNLineStyleLayer(identifier: "ios-route-line", source: source)
            line.lineColor = NSExpression(forConstantValue: model.world.routeColor)
            line.lineWidth = NSExpression(forConstantValue: 5)
            line.lineJoin = NSExpression(forConstantValue: "round")
            line.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(line)
            ready = true
            routeKey = nil
            renderRoute()
            DispatchQueue.main.async { self.model.mapError = nil }
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {}

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            report("Map could not load. Check your internet connection.")
        }

        func report(_ message: String) {
            DispatchQueue.main.async { self.model.mapError = message }
        }

        func renderRoute() {
            guard let map, let style = map.style else { return }
            let key = model.route?.hashValue ?? 0
            if routeKey != key {
                routeKey = key
                renderedRoute = model.route?.geometry.map(\.clLocationCoordinate2D) ?? []
                let shape: MLNPolylineFeature? = renderedRoute.count > 1
                    ? MLNPolylineFeature(coordinates: &renderedRoute, count: UInt(renderedRoute.count)) : nil
                (style.source(withIdentifier: "ios-route") as? MLNShapeSource)?.shape = shape
            }
            if destinationID != model.destination?.id {
                destinationID = model.destination?.id
                if let annotations = map.annotations { map.removeAnnotations(annotations) }
                if let place = model.destination {
                    let pin = MLNPointAnnotation()
                    pin.coordinate = CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                    pin.title = place.name
                    map.addAnnotation(pin)
                }
            }
        }

        func frameSelection() {
            guard let map else { return }
            if !model.followLocation, let route = model.route, route.geometry.count > 1 {
                var coordinates = route.geometry.map(\.clLocationCoordinate2D)
                map.setVisibleCoordinates(&coordinates, count: UInt(coordinates.count),
                                          edgePadding: UIEdgeInsets(top: 150, left: 50, bottom: 330, right: 50), animated: true)
            } else if !model.followLocation, let place = model.destination {
                map.setCenter(CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
                              zoomLevel: 15, animated: true)
            } else if let fix = model.fix {
                map.setCenter(fix.coordinate, zoomLevel: model.navigating ? 17 : 15, animated: true)
            }
        }

        @objc func dropPin(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, !model.navigating, let map else { return }
            let coordinate = map.convert(recognizer.location(in: map), toCoordinateFrom: map)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            model.select(Place(id: "pin:\(UUID().uuidString)", name: "Dropped pin", address: "Selected on the map",
                               coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)))
        }

        @objc func panned(_ recognizer: UIPanGestureRecognizer) {
            if recognizer.state == .began { model.followLocation = false }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
