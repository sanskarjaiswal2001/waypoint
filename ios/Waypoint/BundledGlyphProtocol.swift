import Foundation
import MapLibre
import WaypointKit

/// Serve the shared font blocks locally, falling back to the provider for other scripts.
final class BundledGlyphProtocol: URLProtocol {
    private var downloadTask: URLSessionDataTask?

    static func install() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForResource = 30
        configuration.protocolClasses = [BundledGlyphProtocol.self] + (configuration.protocolClasses ?? [])
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = configuration
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url.map(BundledGlyphStore.handles) ?? false
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let parts = url.pathComponents
        if let resource = BundledGlyphStore().load(url) {
            client?.urlProtocol(self, didReceive: resource.response, cacheStoragePolicy: .allowed)
            client?.urlProtocol(self, didLoad: resource.data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let fallback = URL(string: "https://tiles.openfreemap.org/fonts/Noto%20Sans%20Regular/" + parts[3])!
        downloadTask = URLSession.shared.dataTask(with: fallback) { [weak self] data, response, error in
            guard let self else { return }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        downloadTask?.resume()
    }

    override func stopLoading() { downloadTask?.cancel() }
}
