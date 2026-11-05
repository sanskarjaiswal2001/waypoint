import Foundation

public enum NavigationSharing {
    public typealias Headers = @Sendable (URL) async throws -> (Int, String?)
    private static let hosts: Set<String> = ["maps.app.goo.gl", "goo.gl", "www.google.com", "google.com", "maps.google.com"]
    public static func supportedURL(_ value: String) -> URL? {
        guard let parts = URLComponents(string: value), parts.scheme == "https", let host = parts.host, hosts.contains(host),
              parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443,
              parts.fragment == nil else { return nil }
        if ["www.google.com", "google.com", "goo.gl"].contains(host), parts.path != "/maps", !parts.path.hasPrefix("/maps/") { return nil }
        return parts.url
    }
    public static func isDestinationInput(_ value: String) -> Bool {
        value.hasPrefix("geo:") || value.hasPrefix("google.navigation:") || value.lowercased().contains("https://") || value.range(of: #"^[+\-0-9.]+\s*,"#, options: .regularExpression) != nil
    }
    public static func parseText(_ value: String) -> NavigationImport? {
        guard value.count <= 4096, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0) }) else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("geo:") || text.hasPrefix("google.navigation:") { return NavigationImport.parse(text) }
        let regex = try! NSRegularExpression(pattern: #"https://[^\s<>]+"#, options: .caseInsensitive)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        if !matches.isEmpty || text.lowercased().hasPrefix("http") {
            guard matches.count == 1, let range = Range(matches[0].range, in: text),
                  let url = supportedURL(String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,)]"))) else { return nil }
            let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            if ["maps.app.goo.gl", "goo.gl"].contains(parts.host!) { return .link(url) }
            let parameters = (parts.queryItems ?? []).filter { ["destination", "daddr", "query", "q"].contains($0.name) }
            if !parameters.isEmpty { guard parameters.count == 1, let value = parameters[0].value else { return nil }; return address(value) }
            let coordinate = try! NSRegularExpression(pattern: #"!3d([+\-0-9.]+)!4d([+\-0-9.]+)"#)
            let encoded = url.absoluteString
            if let match = coordinate.firstMatch(in: encoded, range: NSRange(encoded.startIndex..., in: encoded)),
               let lat = Range(match.range(at: 1), in: encoded), let lon = Range(match.range(at: 2), in: encoded) {
                return address("\(encoded[lat]),\(encoded[lon])")
            }
            let segments = parts.percentEncodedPath.split(separator: "/").map(String.init)
            if let index = segments.firstIndex(of: "place"), index + 1 < segments.count,
               let name = segments[index + 1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding { return address(name) }
            return nil
        }
        return address(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
    }
    private static func address(_ value: String) -> NavigationImport? {
        guard !value.hasPrefix("place_id:") else { return nil }
        var parts = URLComponents(); parts.queryItems = [URLQueryItem(name: "q", value: value)]
        return NavigationImport.parse("geo:0,0?" + (parts.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B"))
    }
    public static func resolve(_ url: URL, headers: Headers? = nil) async throws -> NavigationImport? {
        var current = url, visited = Set<URL>()
        let request = headers ?? requestHeaders
        for _ in 0..<4 {
            try Task.checkCancellation()
            guard supportedURL(current.absoluteString) != nil, visited.insert(current).inserted else { return nil }
            if let proposal = parseText(current.absoluteString), case .link = proposal {} else { return parseText(current.absoluteString) }
            let (code, location) = try await request(current)
            try Task.checkCancellation()
            guard (300..<400).contains(code), let location, let next = URL(string: location, relativeTo: current)?.absoluteURL,
                  let allowed = supportedURL(next.absoluteString) else { return nil }
            current = allowed
        }
        if let proposal = parseText(current.absoluteString), case .link = proposal { return nil }
        return parseText(current.absoluteString)
    }
    private static func requestHeaders(_ url: URL) async throws -> (Int, String?) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 5
        let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url); request.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        return (response.statusCode, response.value(forHTTPHeaderField: "Location"))
    }
    public static func mapURL(for place: Place, mode: TravelMode) -> URL {
        var url = URLComponents(string: "https://www.google.com/maps/dir/")!
        url.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: "\(place.coordinate.latitude),\(place.coordinate.longitude)"),
                          URLQueryItem(name: "travelmode", value: mode == .bicycle ? "bicycling" : mode == .walk ? "walking" : "driving")]
        return url.url!
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
