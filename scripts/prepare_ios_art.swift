import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = root.appendingPathComponent("ios/Generated")
let files = FileManager.default
let ui = destination.appendingPathComponent("ui")
try files.createDirectory(at: ui, withIntermediateDirectories: true)

func image(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "WaypointAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode \(url.lastPathComponent)"])
    }
    return image
}
func save(_ image: CGImage, _ url: URL) throws {
    guard let target = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "WaypointAssets", code: 2)
    }
    CGImageDestinationAddImage(target, image, nil)
    guard CGImageDestinationFinalize(target) else { throw NSError(domain: "WaypointAssets", code: 3) }
}
let drawables = root.appendingPathComponent("app/src/main/res/drawable-nodpi")
for url in try files.contentsOfDirectory(at: drawables, includingPropertiesForKeys: nil) {
    let name = url.deletingPathExtension().lastPathComponent
    if name.hasPrefix("world_emblem_") || name.hasPrefix("pixel_") || name.hasPrefix("onboarding_") {
        try save(image(url), ui.appendingPathComponent(name + ".png"))
    } else if name.hasPrefix("art_") {
        let target = ui.appendingPathComponent(url.lastPathComponent)
        if files.fileExists(atPath: target.path) { try files.removeItem(at: target) }
        try files.copyItem(at: url, to: target)
    }
}
let kinds = ["place", "food", "cafe", "pub", "stay", "fuel", "parking", "shop", "sights", "health", "nature", "cash"]
for url in try files.contentsOfDirectory(at: root.appendingPathComponent("app/src/main/assets/poi"), includingPropertiesForKeys: nil) where url.pathExtension == "webp" {
    let atlas = try image(url)
    let name = url.deletingPathExtension().lastPathComponent
    if atlas.width == 512 && atlas.height == 384 {
        for (index, kind) in kinds.enumerated() {
            guard let tile = atlas.cropping(to: CGRect(x: index % 4 * 128, y: index / 4 * 128, width: 128, height: 128)) else { fatalError("Invalid atlas") }
            try save(tile, ui.appendingPathComponent("poi_\(name)_\(kind).png"))
        }
    } else {
        try save(atlas, ui.appendingPathComponent("poi_\(name).png"))
    }
}
var names = [String: String]()
for url in try files.contentsOfDirectory(at: destination.appendingPathComponent("fonts"), includingPropertiesForKeys: nil) {
    guard let data = CGDataProvider(url: url as CFURL), let font = CGFont(data), let name = font.postScriptName else { fatalError("Invalid font") }
    names[url.deletingPathExtension().lastPathComponent] = name as String
}
try JSONSerialization.data(withJSONObject: names, options: [.sortedKeys]).write(to: destination.appendingPathComponent("font-names.json"))
print("Staged shared artwork, POI atlases and \(names.count) UI fonts")
