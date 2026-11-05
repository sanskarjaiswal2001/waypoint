import Foundation

public struct Coordinate: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    public func distance(to other: Coordinate) -> Double {
        let radians = Double.pi / 180
        let lat = (other.latitude - latitude) * radians
        let lon = (other.longitude - longitude) * radians
        let a = pow(sin(lat / 2), 2) + cos(latitude * radians) * cos(other.latitude * radians) * pow(sin(lon / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, min(1, a))), sqrt(max(0, 1 - a)))
    }
}

public struct Place: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let coordinate: Coordinate
    public let kind: String
    public let source: String

    public init(id: String, name: String, address: String, coordinate: Coordinate, kind: String = "place", source: String = "") {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.kind = kind
        self.source = source
    }

    private enum CodingKeys: String, CodingKey { case id, name, address, coordinate, kind, source }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        address = try values.decode(String.self, forKey: .address)
        coordinate = try values.decode(Coordinate.self, forKey: .coordinate)
        kind = try values.decodeIfPresent(String.self, forKey: .kind) ?? "place"
        source = try values.decodeIfPresent(String.self, forKey: .source) ?? ""
    }
}

public enum TravelMode: String, CaseIterable, Codable, Sendable {
    case car, motorcycle, walk

    public var title: String {
        switch self {
        case .car: return "Car"
        case .motorcycle: return "Motorcycle"
        case .walk: return "Walk"
        }
    }

    public var costing: String {
        switch self {
        case .car: return "auto"
        case .motorcycle: return "motorcycle"
        case .walk: return "pedestrian"
        }
    }
}

public enum ServiceError: LocalizedError {
    case invalidResponse, invalidCoordinate, noRoute, tooLarge, http(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The map service returned an invalid response. Please try again."
        case .invalidCoordinate: return "A valid location is needed. Tap Locate and try again."
        case .noRoute: return "No route found for this travel mode. Try another destination."
        case .tooLarge: return "The response is too large. Try a shorter route or search."
        case .http(429): return "The map service is busy. Please try again shortly."
        case .http: return "The map service is unavailable. Check your connection and try again."
        }
    }
}
