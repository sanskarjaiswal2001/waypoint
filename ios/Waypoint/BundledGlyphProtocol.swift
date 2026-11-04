import Foundation
import MapLibre

/// Serve the shared font blocks locally, falling back to the provider for other scripts.
final class BundledGlyphProtocol: URLProtocol {
    private var task: URLSessionDataTask?

    static func install() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [BundledGlyphProtocol.self] + (configuration.protocolClasses ?? [])
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = configuration
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.host == "tiles.openfreemap.org" else { return false }
        let parts = url.pathComponents
        return parts.count == 4 && parts[1] == "fonts" && parts[2].hasPrefix("Waypoint ")
            && parts[3].range(of: #"^\d+-\d+\.pbf$"#, options: .regularExpression) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let parts = url.pathComponents
        if let resource = Bundle.main.url(forResource: parts[3], withExtension: nil, subdirectory: "glyphs/" + parts[2]),
           let data = try? Data(contentsOf: resource) {
            let response = URLResponse(url: url, mimeType: "application/x-protobuf", expectedContentLength: data.count, textEncodingName: nil)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let fallback = URL(string: "https://tiles.openfreemap.org/fonts/Noto%20Sans%20Regular/" + parts[3])!
        task = URLSession.shared.dataTask(with: fallback) { [weak self] data, response, error in
            guard let self else { return }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task?.resume()
    }

    override func stopLoading() { task?.cancel() }
}
