import UIKit
import XCTest
@testable import Waypoint

final class WorldResourceTests: XCTestCase {
    func testEveryStagedWorldHasArtworkTypographyVehiclesAndVoice() throws {
        SharedArt.install()
        XCTAssertFalse(World.all.isEmpty)
        XCTAssertEqual(Set(World.all.map(\.id)).count, World.all.count)
        for world in World.all {
            XCTAssertNotNil(SharedArt.image("world_emblem_\(world.id)"), world.id)
            XCTAssertNotNil(SharedArt.image("art_\(world.id)"), world.id)
            XCTAssertNotNil(world.vehicle, world.id)
            XCTAssertNotNil(world.mapArt, world.id)
            XCTAssertNotNil(world.hudPalette, world.id)
            let voice = try XCTUnwrap(world.voice, world.id)
            XCTAssertEqual(voice.openings.count, 3, world.id)
            XCTAssertEqual(voice.cues.count, 3, world.id)
            XCTAssertEqual(voice.arrivals.count, 3, world.id)
            XCTAssertNotNil(UIFont(name: SharedArt.names[world.titleFontFile] ?? "", size: 20), world.id)
            XCTAssertNotNil(UIFont(name: SharedArt.names[world.hudFontFile] ?? "", size: 20), world.id)
            XCTAssertNoThrow(try world.styleURL())
        }
        let westernVoice = try XCTUnwrap(World.all.first(where: { $0.id == "old_west" })?.voice)
        XCTAssertEqual(westernVoice.pitch, 0.94, accuracy: 0.001)
        XCTAssertEqual(westernVoice.rate, 0.97, accuracy: 0.001)
    }
    func testAllBundledFontsRegisterWithDistinctPostScriptNames() {
        SharedArt.install()
        XCTAssertEqual(Set(SharedArt.names.values).count, SharedArt.names.count)
        for (file, name) in SharedArt.names { XCTAssertNotNil(UIFont(name: name, size: 20), file) }
    }
    func testEveryWorldTransportHasVisiblePixelsInsideTransparentBounds() throws {
        for world in World.all {
            let livery = try XCTUnwrap(world.vehicle)
            for kind in [livery.car, livery.bike, "BICYCLE"] {
                let image = VehicleArtwork.image(livery, kind: kind)
                let cg = try XCTUnwrap(image.cgImage)
                let width = cg.width, height = cg.height
                var pixels = [UInt8](repeating: 0, count: width * height * 4)
                pixels.withUnsafeMutableBytes { bytes in
                    let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
                }
                let opaque = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] != 0 }.count
                XCTAssertGreaterThan(opaque, 100, "\(world.id) \(kind)")
                for x in 0..<width {
                    XCTAssertEqual(pixels[x * 4 + 3], 0)
                    XCTAssertEqual(pixels[((height - 1) * width + x) * 4 + 3], 0)
                }
                for y in 0..<height {
                    XCTAssertEqual(pixels[(y * width) * 4 + 3], 0)
                    XCTAssertEqual(pixels[(y * width + width - 1) * 4 + 3], 0)
                }
            }
        }
    }
}
