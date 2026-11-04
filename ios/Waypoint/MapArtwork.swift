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
                style.setImage(education(world), forName: "poi-\(kind)")
            }
        }
        style.setImage(player(world), forName: "nav-arrow")
        style.setImage(unknown(world), forName: "position-uncertain")
        style.setImage(destination(world), forName: "destination-marker")
    }
    private static func ink(_ w: World) -> UIColor {
        if w.id == "saints" { return UIColor(hex: "FFDA45") }
        if w.id == "green_terminal" { return UIColor(hex: "A4F780") }
        if ["night_city","bridges","hyrule","starfield"].contains(w.id) { return UIColor(hex: "7DDDEC") }
        if ["rivia","lands_between","assassin","hogwarts"].contains(w.id) { return UIColor(hex: "ECD797") }
        return .white
    }
    private static func render(_ width: CGFloat, _ height: CGFloat, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { draw($0.cgContext) }
    }
    static func player(_ w: World) -> UIImage {
        render(96, 104) { c in
            let p = UIBezierPath()
            switch w.id {
            case "old_west", "kingdom":
                p.move(to: CGPoint(x: 48, y: 8)); p.addCurve(to: CGPoint(x: 19, y: 70), controlPoint1: CGPoint(x: 28, y: 34), controlPoint2: CGPoint(x: 12, y: 47)); p.addCurve(to: CGPoint(x: 77, y: 70), controlPoint1: CGPoint(x: 28, y: 99), controlPoint2: CGPoint(x: 71, y: 99)); p.addCurve(to: CGPoint(x: 48, y: 8), controlPoint1: CGPoint(x: 83, y: 47), controlPoint2: CGPoint(x: 68, y: 34)); p.close()
                UIColor.black.setStroke(); p.lineWidth = 10; p.stroke(); UIColor.white.setFill(); p.fill(); c.setFillColor(UIColor.black.cgColor); c.fillEllipse(in: CGRect(x: 32, y: 49, width: 32, height: 32))
            case "pixel":
                c.setShouldAntialias(false); c.setFillColor(UIColor.black.cgColor)
                for r in [CGRect(x: 38,y: 8,width: 20,height: 20),CGRect(x: 30,y: 28,width: 36,height: 58),CGRect(x: 22,y: 44,width: 52,height: 30)] { c.fill(r) }
                c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 42,y: 16,width: 12,height: 62)); c.fill(CGRect(x: 30,y: 52,width: 36,height: 14))
            case "ctos", "lands_between", "hogwarts":
                c.setFillColor(UIColor.black.cgColor); c.fillEllipse(in: CGRect(x: 21,y: 27,width: 54,height: 54)); c.setStrokeColor(ink(w).cgColor); c.setLineWidth(5); c.strokeEllipse(in: CGRect(x: 26,y: 32,width: 44,height: 44))
                c.setFillColor(ink(w).cgColor); c.fillEllipse(in: CGRect(x: 42,y: 48,width: 12,height: 12)); p.move(to: CGPoint(x: 48,y: 9)); p.addLine(to: CGPoint(x: 39,y: 29)); p.addLine(to: CGPoint(x: 57,y: 29)); p.close(); ink(w).setFill(); p.fill()
            default:
                p.move(to: CGPoint(x: 48,y: 9)); p.addLine(to: CGPoint(x: 81,y: 87)); p.addLine(to: CGPoint(x: 48,y: 68)); p.addLine(to: CGPoint(x: 15,y: 87)); p.close()
                UIColor.black.setStroke(); p.lineWidth = 9; p.lineJoinStyle = .round; p.stroke(); ink(w).setFill(); ink(w).setStroke(); p.lineWidth = 7
                if ["night_city","bridges","spider"].contains(w.id) { p.stroke() } else { p.fill() }
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
            if ["night_city","bridges","hyrule","spider","ghost","starfield","just_cause"].contains(w.id) {
                c.move(to: CGPoint(x:40,y:8)); c.addLines(between: [CGPoint(x:72,y:40),CGPoint(x:40,y:72),CGPoint(x:8,y:40),CGPoint(x:40,y:8)]); c.strokePath(); c.move(to: CGPoint(x:40,y:23)); c.addLine(to: CGPoint(x:40,y:57)); c.move(to: CGPoint(x:23,y:40)); c.addLine(to: CGPoint(x:57,y:40)); c.strokePath()
            } else {
                c.strokeEllipse(in: CGRect(x:16,y:16,width:48,height:48))
                if ["old_west","kingdom","mafia"].contains(w.id) { c.move(to: CGPoint(x:15,y:15)); c.addLine(to: CGPoint(x:65,y:65)); c.move(to: CGPoint(x:15,y:65)); c.addLine(to: CGPoint(x:65,y:15)); c.strokePath() }
                else { c.fillEllipse(in: CGRect(x:31,y:31,width:18,height:18)); c.setLineWidth(2); c.strokeEllipse(in: CGRect(x:9,y:9,width:62,height:62)) }
            }
        }
    }
    private static func education(_ w: World) -> UIImage {
        render(64, 64) { c in
            c.setFillColor(UIColor(hex: "141C1D").cgColor); c.fillEllipse(in: CGRect(x:5,y:5,width:54,height:54)); c.setStrokeColor(ink(w).cgColor); c.setLineWidth(2)
            c.strokeEllipse(in: CGRect(x:5,y:5,width:54,height:54)); c.move(to: CGPoint(x:13,y:25)); c.addLines(between: [CGPoint(x:32,y:16),CGPoint(x:51,y:25),CGPoint(x:32,y:34),CGPoint(x:13,y:25)]); c.move(to: CGPoint(x:21,y:30)); c.addLine(to: CGPoint(x:21,y:41)); c.addQuadCurve(to: CGPoint(x:43,y:41), control: CGPoint(x:32,y:49)); c.addLine(to: CGPoint(x:43,y:30)); c.move(to: CGPoint(x:51,y:25)); c.addLine(to: CGPoint(x:51,y:43)); c.strokePath()
        }
    }
}
