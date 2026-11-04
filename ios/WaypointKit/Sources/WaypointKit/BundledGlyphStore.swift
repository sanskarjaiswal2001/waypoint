import Foundation

/// Local font resources served through the map's HTTPS resource transport.
public struct BundledGlyphStore {
    private let bundleURL: URL

    public init(bundleURL: URL = Bundle.main.bundleURL) { self.bundleURL = bundleURL }

    public static func handles(_ url: URL) -> Bool {
        let parts = url.pathComponents
        return url.host == "tiles.openfreemap.org" && parts.count == 4
            && parts[1] == "fonts" && parts[2].hasPrefix("Waypoint ")
            && parts[3].range(of: #"^\d+-\d+\.pbf$"#, options: .regularExpression) != nil
    }

    public func load(_ url: URL) -> (data: Data, response: URLResponse)? {
        guard Self.handles(url) else { return nil }
        let parts = url.pathComponents
        let resource = bundleURL.appendingPathComponent("glyphs", isDirectory: true)
            .appendingPathComponent(parts[2], isDirectory: true).appendingPathComponent(parts[3])
        guard let data = try? Data(contentsOf: resource) else { return nil }
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": "application/x-protobuf",
            "Content-Length": String(data.count)
        ]) else { return nil }
        return (data, response)
    }
}
