import MapLibre
import UIKit

/// Player, destination and discovery markers follow the Android cartography.
enum MapArtwork {
    static let kinds = ["place","food","cafe","pub","stay","fuel","parking","shop","sights","health","nature","cash","education"]
    static func install(_ world: World, in style: MLNStyle) {
        for kind in kinds {
            if let image = SharedArt.image("poi_\(world.id)_\(kind)"), let cg = image.cgImage {
                style.setImage(UIImage(cgImage: cg, scale: 4, orientation: .up), forName: "poi-\(kind)")
            } else {
                let fallback = generatedPOI(kind, world)
                if let cg = fallback.cgImage { style.setImage(UIImage(cgImage: cg, scale: 2, orientation: .up), forName: "poi-\(kind)") }
            }
        }
        style.setImage(player(world), forName: "nav-arrow")
        style.setImage(unknown(world), forName: "position-uncertain")
        style.setImage(destination(world), forName: "destination-marker")
        if let livery = world.vehicle {
            for (name, kind) in [("nav-car", livery.car), ("nav-motorcycle", livery.bike), ("nav-bicycle", "BICYCLE")] {
                style.setImage(VehicleArtwork.image(livery, kind: kind), forName: name)
            }
        }
    }
    private static func ink(_ w: World) -> UIColor {
        switch w.mapArt?.marker {
        case "PHOSPHOR": return UIColor(hex: "A4F780")
        case "TECH", "SHEIKAH": return UIColor(hex: "7DDDEC")
        case "GOLD": return UIColor(hex: "ECD797")
        default: return .white
        }
    }
    private static func render(_ width: CGFloat, _ height: CGFloat, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { draw($0.cgContext) }
    }
    static func player(_ w: World) -> UIImage {
        render(96, 104) { c in
            let p = UIBezierPath()
            switch w.mapArt?.player {
            case "TEARDROP":
                p.move(to: CGPoint(x: 48, y: 8)); p.addCurve(to: CGPoint(x: 19, y: 70), controlPoint1: CGPoint(x: 28, y: 34), controlPoint2: CGPoint(x: 12, y: 47)); p.addCurve(to: CGPoint(x: 77, y: 70), controlPoint1: CGPoint(x: 28, y: 99), controlPoint2: CGPoint(x: 71, y: 99)); p.addCurve(to: CGPoint(x: 48, y: 8), controlPoint1: CGPoint(x: 83, y: 47), controlPoint2: CGPoint(x: 68, y: 34)); p.close()
                UIColor.black.setStroke(); p.lineWidth = 10; p.stroke(); UIColor.white.setFill(); p.fill(); c.setFillColor(UIColor.black.cgColor); c.fillEllipse(in: CGRect(x: 32, y: 49, width: 32, height: 32))
            case "PIXEL":
                c.setShouldAntialias(false); c.setFillColor(UIColor.black.cgColor)
                for r in [CGRect(x: 38,y: 8,width: 20,height: 20),CGRect(x: 30,y: 28,width: 36,height: 58),CGRect(x: 22,y: 44,width: 52,height: 30)] { c.fill(r) }
                c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 42,y: 16,width: 12,height: 62)); c.fill(CGRect(x: 30,y: 52,width: 36,height: 14))
            case "RING":
                c.setFillColor(UIColor.black.cgColor); c.fillEllipse(in: CGRect(x: 21,y: 27,width: 54,height: 54)); c.setStrokeColor(ink(w).cgColor); c.setLineWidth(5); c.strokeEllipse(in: CGRect(x: 26,y: 32,width: 44,height: 44))
                c.setFillColor(ink(w).cgColor); c.fillEllipse(in: CGRect(x: 42,y: 48,width: 12,height: 12)); p.move(to: CGPoint(x: 48,y: 9)); p.addLine(to: CGPoint(x: 39,y: 29)); p.addLine(to: CGPoint(x: 57,y: 29)); p.close(); ink(w).setFill(); p.fill()
            default:
                p.move(to: CGPoint(x: 48,y: 9)); p.addLine(to: CGPoint(x: 81,y: 87)); p.addLine(to: CGPoint(x: 48,y: 68)); p.addLine(to: CGPoint(x: 15,y: 87)); p.close()
                UIColor.black.setStroke(); p.lineWidth = 9; p.lineJoinStyle = .round; p.stroke(); ink(w).setFill(); ink(w).setStroke(); p.lineWidth = 7
                if w.mapArt?.player == "CHEVRON" { p.stroke() } else { p.fill() }
            }
        }
    }
    static func unknown(_ w: World) -> UIImage {
        render(64, 64) { c in
            let p = UIBezierPath()
            for points in [[CGPoint(x:25,y:11),CGPoint(x:11,y:11),CGPoint(x:11,y:25)],[CGPoint(x:39,y:11),CGPoint(x:53,y:11),CGPoint(x:53,y:25)],[CGPoint(x:11,y:39),CGPoint(x:11,y:53),CGPoint(x:25,y:53)],[CGPoint(x:53,y:39),CGPoint(x:53,y:53),CGPoint(x:39,y:53)]] { p.move(to: points[0]); p.addLine(to: points[1]); p.addLine(to: points[2]) }
            UIColor.black.setStroke(); p.lineWidth = 9; p.stroke(); ink(w).setStroke(); p.lineWidth = 5; p.stroke()
        }
    }
    static func destination(_ w: World) -> UIImage {
        render(80, 80) { c in
            c.setStrokeColor(w.routeColor.cgColor); c.setFillColor(w.routeColor.cgColor); c.setLineWidth(5)
            if ["TECH", "SHEIKAH", "DIAMOND", "SURVEY"].contains(w.mapArt?.marker ?? "") {
                c.move(to: CGPoint(x:40,y:8)); c.addLines(between: [CGPoint(x:72,y:40),CGPoint(x:40,y:72),CGPoint(x:8,y:40),CGPoint(x:40,y:8)]); c.strokePath(); c.move(to: CGPoint(x:40,y:23)); c.addLine(to: CGPoint(x:40,y:57)); c.move(to: CGPoint(x:23,y:40)); c.addLine(to: CGPoint(x:57,y:40)); c.strokePath()
            } else {
                c.strokeEllipse(in: CGRect(x:16,y:16,width:48,height:48))
                if w.mapArt?.marker == "INK" { c.move(to: CGPoint(x:15,y:15)); c.addLine(to: CGPoint(x:65,y:65)); c.move(to: CGPoint(x:15,y:65)); c.addLine(to: CGPoint(x:65,y:15)); c.strokePath() }
                else { c.fillEllipse(in: CGRect(x:31,y:31,width:18,height:18)); c.setLineWidth(2); c.strokeEllipse(in: CGRect(x:9,y:9,width:62,height:62)) }
            }
        }
    }
    private static func generatedPOI(_ kind: String, _ w: World) -> UIImage {
        let symbols = ["place":"mappin", "food":"fork.knife", "cafe":"cup.and.saucer.fill", "pub":"wineglass.fill", "stay":"bed.double.fill", "fuel":"fuelpump.fill", "parking":"parkingsign", "shop":"bag.fill", "sights":"building.columns.fill", "health":"cross.case.fill", "nature":"leaf.fill", "cash":"banknote", "education":"graduationcap.fill"]
        return render(64, 64) { c in
            let rect = CGRect(x: 5, y: 5, width: 54, height: 54)
            let art = w.mapArt?.marker ?? "SILHOUETTE"
            var fill = UIColor(hex: "10191D"), border = ink(w)
            let shape: UIBezierPath
            switch art {
            case "PHOSPHOR": fill = UIColor(hex: "07160A"); shape = UIBezierPath(roundedRect: rect, cornerRadius: 5)
            case "SILHOUETTE", "SILVER", "INK":
                fill = UIColor(hex: "141C1D"); if art == "INK" { border = UIColor(hex: "E9DCBA") }; shape = UIBezierPath(ovalIn: rect)
            case "PASTEL", "RACING":
                let colors = ["food":"387C50", "cafe":"D98C29", "pub":"AA6129", "stay":"3B83A9", "shop":"A35276", "sights":"6657A8", "nature":"427F50", "health":"B15354", "cash":"438E88"]
                fill = UIColor(hex: colors[kind] ?? "337C98"); shape = UIBezierPath(roundedRect: rect, cornerRadius: art == "RACING" ? 2 : 10)
            case "PIXEL":
                c.setShouldAntialias(false); fill = UIColor(hex: "263226"); border = UIColor(hex: "B5C7A8"); shape = UIBezierPath(rect: rect)
            case "GOLD": fill = UIColor(hex: "4C452D"); shape = UIBezierPath(ovalIn: CGRect(x: 7, y: 7, width: 50, height: 50))
            default:
                shape = UIBezierPath(); shape.move(to: CGPoint(x: 32, y: 2)); shape.addLine(to: CGPoint(x: 62, y: 32)); shape.addLine(to: CGPoint(x: 32, y: 62)); shape.addLine(to: CGPoint(x: 2, y: 32)); shape.close()
                if art == "DIAMOND" { border = w.routeColor }
            }
            fill.setFill(); shape.fill(); border.setStroke(); shape.lineWidth = art == "PIXEL" ? 4 : 2.5; shape.stroke()
            if art == "GOLD" { c.setStrokeColor(border.cgColor); c.setLineWidth(3); c.strokeEllipse(in: CGRect(x: 3, y: 3, width: 58, height: 58)) }
            UIImage(systemName: symbols[kind] ?? "mappin", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))?.withTintColor(ink(w), renderingMode: .alwaysOriginal).draw(in: CGRect(x: 17, y: 17, width: 30, height: 30))
        }
    }
}
