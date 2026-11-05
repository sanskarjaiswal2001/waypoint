import Foundation

public struct IOSRelease: Equatable, Sendable {
    public let version: String
    public let url: URL

    public static func newerRelease(in data: Data, currentVersion: String) throws -> Self? {
        struct Release: Decodable { let tag_name: String; let draft: Bool; let html_url: String }
        func numbers(_ version: String) -> [Int]? {
            let parts = version.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 3, version.count <= 24, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }), parts.compactMap({ Int($0) }).count == 3 else { return nil }
            return parts.compactMap { Int($0) }
        }
        guard data.count <= 2_000_000, let current = numbers(currentVersion) else { throw ServiceError.invalidResponse }
        let releases = try JSONDecoder().decode([Release].self, from: data)
        return releases.compactMap { release -> Self? in
            guard !release.draft, release.tag_name.hasPrefix("ios-v") else { return nil }
            let version = String(release.tag_name.dropFirst(5))
            guard let parsed = numbers(version), current.lexicographicallyPrecedes(parsed),
                  let url = URL(string: release.html_url), let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  components.scheme == "https", components.host == "github.com", components.user == nil, components.password == nil,
                  components.port == nil, components.query == nil, components.fragment == nil,
                  components.path == "/" + ProjectLinks.repository + "/releases/tag/" + release.tag_name else { return nil }
            return Self(version: version, url: url)
        }.max { lhs, rhs in (numbers(lhs.version) ?? []).lexicographicallyPrecedes(numbers(rhs.version) ?? []) }
    }
}
