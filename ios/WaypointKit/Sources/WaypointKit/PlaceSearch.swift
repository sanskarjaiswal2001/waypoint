import Foundation

public enum PlaceMatcher {
    public static func normalize(_ text: String) -> String {
        let folded = String(text.prefix(256)).folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static let generic: Set<String> = ["railway", "railroad", "train", "station", "stn", "rly", "restaurant", "hotel", "near", "in"]
    private static func core(_ text: String) -> String {
        normalize(text).split(separator: " ").map(String.init).filter { !generic.contains($0) }.joined(separator: " ")
    }
    private static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a.count >= 3 && b.hasPrefix(a) { return 0.92 }
        let a = Array(a), b = Array(b)
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, right) in b.enumerated() {
                current[j + 1] = min(current[j] + 1, previous[j + 1] + 1, previous[j] + (left == right ? 0 : 1))
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }

    public static func score(_ query: String, _ place: Place) -> Double {
        let normalized = normalize(query)
        let categories: Set<String>
        switch normalized {
        case "food", "restaurant", "restaurants": categories = ["restaurant", "fast_food", "food_court", "food"]
        case "coffee", "cafe", "cafes": categories = ["cafe", "coffee_shop"]
        case "fuel", "petrol", "petrol station", "gas station": categories = ["fuel"]
        case "parking": categories = ["parking"]
        case "hotel", "hotels": categories = ["hotel", "motel", "hostel", "guest_house"]
        default: categories = []
        }
        if categories.contains(place.kind) { return 1 }
        let q = core(query).isEmpty ? normalized : core(query)
        let name = core(place.name).isEmpty ? normalize(place.name) : core(place.name)
        guard !q.isEmpty else { return 0 }
        let compact = similarity(q.replacingOccurrences(of: " ", with: ""), name.replacingOccurrences(of: " ", with: ""))
        let tokens = q.split(separator: " ").map(String.init)
        let candidates = (name + " " + normalize(place.address)).split(separator: " ").map(String.init)
        let tokenScore = tokens.reduce(0.0) { sum, token in sum + (candidates.map { similarity(token, $0) }.max() ?? 0) } / Double(tokens.count)
        var result = max(compact, tokenScore * 0.96)
        let stationWords: Set<String> = ["railway", "railroad", "train", "station", "stn", "rly"]
        if !stationWords.isDisjoint(with: normalized.split(separator: " ").map(String.init)),
           !["station", "halt", "train_station", "geocoder"].contains(place.kind),
           !normalize(place.name).contains("station") { result *= 0.35 }
        return result
    }

    public static func ranked(_ query: String, near: Coordinate?, places: [Place]) -> [Place] {
        let scored = places.enumerated().filter { $0.element.coordinate.isValid }.map { (place: $0.element, score: score(query, $0.element), index: $0.offset) }
        let best = scored.map(\.score).max() ?? 0
        let cutoff = best >= 0.88 ? max(0.52, best - 0.12) : 0.52
        let sorted = scored.filter { $0.score >= cutoff }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if let near, near.isValid {
                let lhs = near.distance(to: $0.place.coordinate), rhs = near.distance(to: $1.place.coordinate)
                if lhs != rhs { return lhs < rhs }
            }
            return $0.index < $1.index
        }
        var result = [Place]()
        for item in sorted where result.count < 12 {
            if !result.contains(where: { $0.id == item.place.id || normalize($0.name) == normalize(item.place.name) && $0.coordinate.distance(to: item.place.coordinate) < 100 }) { result.append(item.place) }
        }
        return result
    }

    public static func variants(_ query: String) -> [String] {
        let cleaned = query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let spaced = cleaned.replacingOccurrences(of: "(?i)([\\p{L}]{4,})(more|morh|chowk|junction)$", with: "$1 $2", options: .regularExpression)
        return cleaned == spaced ? [cleaned] : [cleaned, spaced]
    }
}

public struct SearchAliases: Sendable {
    private var entries = [String: String]()
    public init(_ values: [String: String] = [:]) {
        for (key, value) in values.sorted(by: { $0.key < $1.key }).prefix(100) {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  key.count <= 256, value.count <= 256,
                  !key.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                  !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { continue }
            entries[PlaceMatcher.normalize(key)] = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    public func resolve(_ query: String) -> String { entries[PlaceMatcher.normalize(query)] ?? query }
}

public struct PlaceSearchResult: Sendable {
    public let places: [Place]
    public let note: String?
}

/// Provider queries run sequentially; successful searches use a bounded memory-only cache.
public actor PlaceSearch {
    public typealias Provider = @Sendable (String, Coordinate?) async throws -> [Place]
    private let primary: Provider
    private let fallback: Provider?
    private let aliases: SearchAliases
    private let timeout: Duration
    private var cache = [String: [Place]]()
    private var cacheOrder = [String]()

    public init(primary: @escaping Provider, fallback: Provider? = nil, aliases: SearchAliases = SearchAliases(), timeout: Duration = .seconds(9)) {
        self.primary = primary; self.fallback = fallback; self.aliases = aliases; self.timeout = timeout
    }

    public func search(_ query: String, near: Coordinate?, local: [Place] = [], expanded: Bool = false) async throws -> PlaceSearchResult {
        guard query.count <= 256 else { throw ServiceError.invalidQuery }
        guard near?.isValid != false else { throw ServiceError.invalidCoordinate }
        try Task.checkCancellation()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return PlaceSearchResult(places: [], note: nil) }
        let effective = aliases.resolve(query)
        let variants = PlaceMatcher.variants(effective)
        let aliasNote = effective != query ? "Searching for \(effective)" : nil
        let area = near.map { "\(($0.latitude * 100).rounded()):\(($0.longitude * 100).rounded())" } ?? "global"
        let key = "\(PlaceMatcher.normalize(query)):\(area):\(expanded)"
        if let cached = cache[key] { return PlaceSearchResult(places: PlaceMatcher.ranked(effective, near: near, places: cached + local), note: aliasNote) }
        var remote = [Place](), failures = 0, completed = 0
        func lookup(_ provider: @escaping Provider, _ value: String) async throws {
            do {
                let found = try await Self.lookup(provider, value, near: near, timeout: timeout)
                try Task.checkCancellation()
                remote.append(contentsOf: found.prefix(20)); completed += 1
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                failures += 1
            }
        }
        try await lookup(primary, variants[0])
        if let fallback, expanded || !PlaceMatcher.ranked(effective, near: near, places: remote + local).contains(where: { PlaceMatcher.score(effective, $0) >= 0.88 }) {
            try await lookup(fallback, variants[0])
            if variants.count > 1 && PlaceMatcher.ranked(effective, near: near, places: remote + local).isEmpty { try await lookup(fallback, variants[1]) }
        }
        try Task.checkCancellation()
        let places = PlaceMatcher.ranked(effective, near: near, places: remote + local)
        if failures == 0 {
            if cache[key] == nil { cacheOrder.append(key) }
            cache[key] = remote
            while cacheOrder.count > 40 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        }
        let note: String?
        if failures > 0 { note = places.isEmpty ? "Search service unavailable. Try again or drop a pin on the map." : "Some search services are unavailable. Showing the matches found." }
        else if places.isEmpty && completed > 0 { note = "No matching place found. Try another spelling, add the town, or drop a pin on the map." }
        else if !places.contains(where: { PlaceMatcher.score(effective, $0) >= 0.8 }) { note = "Possible matches. Check the name and address before choosing." }
        else { note = aliasNote }
        return PlaceSearchResult(places: places, note: note)
    }

    private static func lookup(_ provider: @escaping Provider, _ query: String, near: Coordinate?, timeout: Duration) async throws -> [Place] {
        try await withThrowingTaskGroup(of: [Place].self) { group in
            group.addTask { try await provider(query, near) }
            group.addTask { try await Task.sleep(for: timeout); throw URLError(.timedOut) }
            defer { group.cancelAll() }
            return try await group.next() ?? []
        }
    }
}
