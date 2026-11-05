import CoreLocation
import WaypointKit

enum ApplePlaceSearch {
    @MainActor static func find(_ query: String, near: Coordinate?) async throws -> [Place] {
        let geocoder = CLGeocoder()
        let region = near.map { CLCircularRegion(center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), radius: 30_000, identifier: "search-area") }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let matches: [CLPlacemark]
            do { matches = try await geocoder.geocodeAddressString(query, in: region, preferredLocale: .current) }
            catch let error as CLError where error.code == .geocodeFoundNoResult { return [] }
            try Task.checkCancellation()
            return matches.prefix(8).compactMap { match in
                guard let location = match.location else { return nil }
                let point = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                guard point.isValid else { return nil }
                func clean(_ value: String) -> String {
                    String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(256)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let name = clean(match.name ?? match.thoroughfare ?? match.locality ?? "Address result")
                guard !name.isEmpty else { return nil }
                let address = [match.subThoroughfare, match.thoroughfare, match.locality, match.administrativeArea, match.country].compactMap { $0 }.map(clean).joined(separator: ", ")
                return Place(id: "apple:\(point.latitude),\(point.longitude):\(name)", name: name, address: address, coordinate: point, kind: "geocoder", source: "Apple geocoder · address match")
            }
        } onCancel: { Task { @MainActor in geocoder.cancelGeocode() } }
    }
}
