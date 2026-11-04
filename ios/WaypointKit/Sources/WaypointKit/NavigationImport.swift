import Foundation

/// A shared destination is a proposal until the user confirms it in the app.
public enum NavigationImport: Equatable, Sendable {
    case point(Coordinate, label: String)
    case search(String)

    public var title: String {
        switch self { case .point(_, let label): return label; case .search(let query): return query }
    }
    public static func parse(_ value: String) -> Self? {
        guard value.count <= 4096, let colon = value.firstIndex(of: ":") else { return nil }
        let scheme = String(value[..<colon])
        guard ["geo", "google.navigation"].contains(scheme) else { return nil }
        let raw = String(value[value.index(after: colon)...].split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
        guard !raw.hasPrefix("//") else { return nil }
        let pieces = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let parameters = scheme == "google.navigation" ? raw : pieces.count > 1 ? String(pieces[1]) : ""
        let queries = parameters.split(separator: "&").filter { $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first == "q" }
        guard queries.count <= 1 else { return nil }
        let encoded: String
        if let query = queries.first { encoded = String(query.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).last ?? "").replacingOccurrences(of: "+", with: " ") }
        else { guard scheme == "geo" else { return nil }; encoded = String(pieces[0]) }
        guard let decoded = encoded.removingPercentEncoding else { return nil }
        let text = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 256, !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
        let pattern = #"^([+-]?[0-9]{1,3}(?:\.[0-9]{1,12})?),\s*([+-]?[0-9]{1,3}(?:\.[0-9]{1,12})?)(?:\s*\(([^()]{1,120})\))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let latRange = Range(match.range(at: 1), in: text), let lonRange = Range(match.range(at: 2), in: text),
           let lat = Double(text[latRange]), let lon = Double(text[lonRange]) {
            let point = Coordinate(latitude: lat, longitude: lon)
            guard point.isValid else { return nil }
            let label = Range(match.range(at: 3), in: text).map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            return .point(point, label: label.isEmpty ? String(format: "Location at %.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), lat, lon) : label)
        }
        guard text.range(of: #"^[+\-0-9.]+\s*,"#, options: .regularExpression) == nil else { return nil }
        return .search(text)
    }
}
