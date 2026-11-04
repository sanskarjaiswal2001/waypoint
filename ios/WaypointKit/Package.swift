// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WaypointKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "WaypointKit", targets: ["WaypointKit"])],
    targets: [
        .target(name: "WaypointKit"),
        .testTarget(name: "WaypointKitTests", dependencies: ["WaypointKit"])
    ]
)
