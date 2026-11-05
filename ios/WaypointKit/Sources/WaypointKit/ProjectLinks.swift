import Foundation

public enum ProjectLinks {
    public static let repository = "the-geeky-couldron/waypoint"
    public static let source = URL(string: "https://github.com/" + repository)!
    public static let releases = source.appendingPathComponent("releases")
    public static let releaseAPI = URL(string: "https://api.github.com/repos/" + repository + "/releases?per_page=50")!
    public static let newIssue = source.appendingPathComponent("issues/new")
    public static let installGuide = source.appendingPathComponent("blob/main/ios/README.md")
}
