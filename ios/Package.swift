// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Waypoint",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Waypoint", targets: ["Waypoint"])],
    dependencies: [
        .package(path: "WaypointKit"),
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", exact: "6.26.1"),
        .package(url: "https://github.com/stadiamaps/ferrostar.git", exact: "0.59.0")
    ],
    targets: [
        .target(
            name: "Waypoint",
            dependencies: [
                "WaypointKit",
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
                .product(name: "FerrostarCore", package: "ferrostar")
            ],
            path: "Waypoint",
            exclude: ["Info.plist"]
        )
    ],
    swiftLanguageModes: [.v5]
)
