import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = root.appendingPathComponent("ios/Generated")
let files = FileManager.default
let ui = destination.appendingPathComponent("ui")
if files.fileExists(atPath: ui.path) { try files.removeItem(at: ui) }
try files.createDirectory(at: ui, withIntermediateDirectories: true)

final class VectorPaths: NSObject, XMLParserDelegate {
    var paths = [[String: String]]()
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "path" { paths.append(attributes) }
    }
}
func vectorColor(_ value: String) -> CGColor {
    let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let number = UInt64(hex, radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((number >> 16) & 255) / 255, green: CGFloat((number >> 8) & 255) / 255,
                   blue: CGFloat(number & 255) / 255, alpha: hex.count == 8 ? CGFloat((number >> 24) & 255) / 255 : 1)
}
func vectorPath(_ value: String) throws -> CGPath {
    let regex = try NSRegularExpression(pattern: "[A-Za-z]|[-+]?(?:[0-9]*\\.)?[0-9]+(?:[eE][-+]?[0-9]+)?")
    let tokens = regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { String(value[Range($0.range, in: value)!]) }
    var index = 0, command = ""
    let path = CGMutablePath()
    func number() throws -> CGFloat {
        guard index < tokens.count, let value = Double(tokens[index]) else { throw CocoaError(.fileReadCorruptFile) }
        index += 1; return CGFloat(value)
    }
    while index < tokens.count {
        if tokens[index].first!.isLetter { command = tokens[index]; index += 1 }
        switch command {
        case "M": path.move(to: CGPoint(x: try number(), y: try number())); command = "L"
        case "L": path.addLine(to: CGPoint(x: try number(), y: try number()))
        case "H": path.addLine(to: CGPoint(x: try number(), y: path.currentPoint.y))
        case "V": path.addLine(to: CGPoint(x: path.currentPoint.x, y: try number()))
        case "Q":
            let control = CGPoint(x: try number(), y: try number())
            path.addQuadCurve(to: CGPoint(x: try number(), y: try number()), control: control)
        case "C":
            let first = CGPoint(x: try number(), y: try number()), second = CGPoint(x: try number(), y: try number())
            path.addCurve(to: CGPoint(x: try number(), y: try number()), control1: first, control2: second)
        case "A":
            let rx = try number(), ry = try number(), rotation = try number(), large = try number(), sweep = try number()
            let start = path.currentPoint, end = CGPoint(x: try number(), y: try number())
            guard rx == ry, rotation == 0, rx > 0 else { throw CocoaError(.fileReadCorruptFile) }
            let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
            let scale = sqrt(max(0, (rx * rx - dx * dx - dy * dy) / (dx * dx + dy * dy))) * (large == sweep ? -1 : 1)
            let center = CGPoint(x: (start.x + end.x) / 2 + scale * dy, y: (start.y + end.y) / 2 - scale * dx)
            path.addArc(center: center, radius: rx, startAngle: atan2(start.y - center.y, start.x - center.x), endAngle: atan2(end.y - center.y, end.x - center.x), clockwise: sweep == 0)
        case "Z": path.closeSubpath(); command = ""
        default: throw CocoaError(.fileReadCorruptFile)
        }
    }
    return path
}
func vectorImage(_ url: URL) throws -> CGImage {
    let delegate = VectorPaths(), parser = XMLParser(contentsOf: url)!
    parser.delegate = delegate
    guard parser.parse(), !delegate.paths.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
    let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: 256); context.scaleBy(x: 4, y: -4)
    context.setLineJoin(.round); context.setLineCap(.round)
    for attributes in delegate.paths {
        let path = try vectorPath(attributes["android:pathData"] ?? "")
        context.addPath(path); context.setFillColor(vectorColor(attributes["android:fillColor"] ?? "#00000000")); context.fillPath()
        if let color = attributes["android:strokeColor"] {
            context.addPath(path); context.setStrokeColor(vectorColor(color)); context.setLineWidth(CGFloat(Double(attributes["android:strokeWidth"] ?? "1") ?? 1)); context.strokePath()
        }
    }
    return context.makeImage()!
}

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
for url in try files.contentsOfDirectory(at: root.appendingPathComponent("app/src/main/res/drawable"), includingPropertiesForKeys: nil)
    where url.lastPathComponent.hasPrefix("world_emblem_") && url.pathExtension == "xml" {
    try save(vectorImage(url), ui.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".png"))
}
for url in try files.contentsOfDirectory(at: root.appendingPathComponent("app/src/main/assets/globe/textures"), includingPropertiesForKeys: nil)
    where url.pathExtension == "png" {
    let base = "art_" + url.deletingPathExtension().lastPathComponent
    if !files.fileExists(atPath: ui.appendingPathComponent(base + ".webp").path) && !files.fileExists(atPath: ui.appendingPathComponent(base + ".png").path) {
        try save(image(url), ui.appendingPathComponent(base + ".png"))
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
