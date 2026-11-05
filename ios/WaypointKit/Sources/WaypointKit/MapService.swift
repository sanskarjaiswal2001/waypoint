import Foundation

public struct MapService: Sendable {
    public init() {}

    public func search(_ query: String, near: Coordinate?) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 256 else { return [] }
        var components = URLComponents(string: "https://photon.komoot.io/api/")!
        components.queryItems = [URLQueryItem(name: "q", value: trimmed),
                                 URLQueryItem(name: "limit", value: "8"),
                                 URLQueryItem(name: "lang", value: "en")]
        if let near, near.isValid {
            components.queryItems! += [URLQueryItem(name: "lat", value: String(near.latitude)),
                                       URLQueryItem(name: "lon", value: String(near.longitude))]
        }
        return try Self.decodePlaces(await fetch(components.url!, limit: 2 * 1024 * 1024, timeout: 9))
    }

    public func routeData(from: Coordinate, to: Coordinate, mode: TravelMode) async throws -> Data {
        let url = try Self.routeURL(from: from, to: to, mode: mode)
        return try RoutePreparation.prepare(await fetch(url, limit: 8 * 1024 * 1024), expectedOrigin: from, expectedDestination: to)
    }

    public static func routeURL(from: Coordinate, to: Coordinate, mode: TravelMode) throws -> URL {
        guard from.isValid, to.isValid else { throw ServiceError.invalidCoordinate }
        if mode == .car {
            return URL(string: "https://router.project-osrm.org/route/v1/driving/\(from.longitude),\(from.latitude);\(to.longitude),\(to.latitude)?overview=full&geometries=polyline6&steps=true")!
        }
        let payload: [String: Any] = [
            "locations": [["lat": from.latitude, "lon": from.longitude], ["lat": to.latitude, "lon": to.longitude]],
            "costing": mode.costing, "format": "osrm", "shape_format": "polyline6",
            "units": "kilometers", "language": "en-US"
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        var components = URLComponents(string: "https://valhalla1.openstreetmap.de/route")!
        components.queryItems = [URLQueryItem(name: "json", value: String(decoding: json, as: UTF8.self))]
        return components.url!
    }

    public static func decodePlaces(_ data: Data) throws -> [Place] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]], features.count <= 8 else {
            throw ServiceError.invalidResponse
        }
        var ids = Set<String>()
        return try features.compactMap { feature in
            guard let geometry = feature["geometry"] as? [String: Any],
                  let point = geometry["coordinates"] as? [Double], point.count == 2,
                  let properties = feature["properties"] as? [String: Any] else { throw ServiceError.invalidResponse }
            let coordinate = Coordinate(latitude: point[1], longitude: point[0])
            guard coordinate.isValid else { throw ServiceError.invalidCoordinate }
            let name = clean(properties["name"] as? String ?? properties["street"] as? String ?? "Dropped pin")
            let address = ["housenumber", "street", "district", "city", "country"].compactMap {
                properties[$0] as? String
            }.map(clean).filter { !$0.isEmpty }.joined(separator: ", ")
            let id = "\(properties["osm_type"] ?? "point"):\(properties["osm_id"] ?? "\(point[0]),\(point[1])")"
            guard ids.insert(id).inserted else { return nil }
            return Place(id: id, name: name, address: address, coordinate: coordinate,
                         kind: clean(properties["osm_value"] as? String ?? "place"), source: "Photon · OpenStreetMap")
        }
    }

    private func fetch(_ url: URL, limit: Int, timeout: TimeInterval = 25) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("WaypointiOS/0.1 (https://github.com/the-geeky-couldron/waypoint)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard response.statusCode == 200 else { throw ServiceError.http(response.statusCode) }
        guard response.expectedContentLength <= limit else { throw ServiceError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < limit else { throw ServiceError.tooLarge }
            data.append(byte)
        }
        return data
    }
}

func clean(_ text: String) -> String {
    String(text.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(200))
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
