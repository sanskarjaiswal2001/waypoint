import UIKit

/// Original transport silhouettes share Android's per-world livery and vehicle choices.
enum VehicleArtwork {
    static func image(_ livery: VehicleLivery, kind: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = livery.pixel ? CGSize(width: 24, height: 26) : CGSize(width: 96, height: 104)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            if livery.pixel { renderer.cgContext.scaleBy(x: 0.25, y: 0.25) }
            let painter = Painter(context: renderer.cgContext, livery: livery)
            painter.draw(kind)
        }
        guard livery.pixel else { return image }
        return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 104), format: format).image { renderer in
            renderer.cgContext.interpolationQuality = .none
            image.draw(in: CGRect(x: 0, y: 0, width: 96, height: 104))
        }
    }
    private final class Painter {
        let c: CGContext
        let body: UIColor, trim: UIColor
        let ink = UIColor(hex: "161D1F"), light = UIColor(hex: "F6F1D8")
        let wire: Bool
        init(context: CGContext, livery: VehicleLivery) {
            c = context; body = UIColor(hex: livery.body); trim = UIColor(hex: livery.trim); wire = livery.wire
            c.setShouldAntialias(!livery.pixel); c.setLineCap(.round); c.setLineJoin(.round)
            c.translateBy(x: 4, y: 4); c.scaleBy(x: 88 / 96, y: 96 / 104)
        }
        func path(_ xy: CGFloat...) -> UIBezierPath {
            let p = UIBezierPath(); p.move(to: CGPoint(x: xy[0], y: xy[1]))
            for index in stride(from: 2, to: xy.count, by: 2) { p.addLine(to: CGPoint(x: xy[index], y: xy[index + 1])) }
            p.close(); return p
        }
        func shape(_ path: UIBezierPath, _ fill: UIColor? = nil, outline: Bool = true) {
            path.lineJoinStyle = .round; path.lineCapStyle = .round
            if outline { light.setStroke(); path.lineWidth = 8; path.stroke(); ink.setStroke(); path.lineWidth = 5; path.stroke() }
            (fill ?? body).setFill(); path.fill()
            if wire && fill == nil { trim.setStroke(); path.lineWidth = 2; path.stroke() }
        }
        func box(_ l: CGFloat, _ t: CGFloat, _ r: CGFloat, _ b: CGFloat, _ color: UIColor? = nil, radius: CGFloat = 0, outline: Bool = true) {
            shape(UIBezierPath(roundedRect: CGRect(x: l, y: t, width: r - l, height: b - t), cornerRadius: radius), color, outline: outline)
        }
        func oval(_ l: CGFloat, _ t: CGFloat, _ r: CGFloat, _ b: CGFloat, _ color: UIColor? = nil, outline: Bool = true) {
            shape(UIBezierPath(ovalIn: CGRect(x: l, y: t, width: r - l, height: b - t)), color, outline: outline)
        }
        func line(_ x: CGFloat, _ y: CGFloat, _ xx: CGFloat, _ yy: CGFloat, _ color: UIColor? = nil, _ width: CGFloat = 3) {
            c.setStrokeColor((color ?? trim).cgColor); c.setLineWidth(width); c.move(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: xx, y: yy)); c.strokePath()
        }
        func draw(_ kind: String) {
            switch kind {
            case "HORSE", "HORNED_STEED", "MACHINE_MOUNT", "CAMEL": mount(kind)
            case "MINECART": minecart()
            case "PIG": pig()
            case "SHIP", "ROWBOAT": boat(kind == "SHIP")
            case "CARRIAGE": carriage()
            case "BROOM": broom()
            case "FLIGHT_UNIT", "POD": machine(kind == "FLIGHT_UNIT")
            case "BICYCLE": bicycle()
            case "MOTORCYCLE", "TRIKE": motorcycle(kind == "TRIKE")
            default: car(kind)
            }
        }
        func car(_ kind: String) {
            let rugged = ["TRUCK", "ROVER"].contains(kind), classic = kind == "CLASSIC_CAR"
            for x: CGFloat in [19, 68] { for y: CGFloat in [24, 67] { box(x, y, x + 9, y + 17, ink, radius: 3) } }
            if kind == "ROVER" { for x: CGFloat in [18, 69] { box(x, 47, x + 9, 59, ink, radius: 3) } }
            if rugged { shape(path(29,13,67,13,73,25,73,88,23,88,23,25)) }
            else if kind == "SPORTS_CAR" { shape(path(34,10,62,10,72,28,70,87,26,87,24,28)) }
            else { box(classic ? 27 : 26, 10, classic ? 69 : 70, 92, radius: classic ? 17 : 14) }
            box(31,31,65,48,ink,radius:4,outline:false); line(34,34,61,34,trim,4)
            box(33,55,63,74,rugged ? ink : trim,radius:4,outline:false)
            line(33,21,39,21,light,4); line(57,21,63,21,light,4)
            if rugged { line(29,58,67,58,trim,4); line(29,70,67,70,trim,4); if kind == "TRUCK" { line(47,52,47,77,body,5) } }
            if kind == "SPORTS_CAR" { box(22,82,74,88,trim,radius:1); line(45,13,45,28); line(51,13,51,28) }
            if classic { line(35,79,61,79,light); line(47,12,47,27) }
        }
        func motorcycle(_ trike: Bool) {
            box(42,7,54,31,ink,radius:5)
            if trike { for x: CGFloat in [23,61] { box(x,73,x+12,96,ink,radius:4) } } else { box(41,75,55,98,ink,radius:5) }
            line(43,25,40,43,light,5); line(53,25,56,43,light,5)
            shape(path(48,29,64,42,62,77,55,87,41,87,34,77,32,42))
            box(30,28,66,34,trim,radius:3); oval(39,38,57,56,trim,outline:false); box(40,61,56,78,ink,radius:5,outline:false)
            if trike { box(24,54,34,78,trim,radius:2); box(62,54,72,78,trim,radius:2) }; line(44,31,52,31,light)
        }
        func mount(_ kind: String) {
            let machine = kind == "MACHINE_MOUNT"
            for x: CGFloat in [25,58] { box(x,42,x+12,57,radius:4); box(x,71,x+12,86,radius:4); line(x+3,83,x+9,83,ink,4) }
            shape(path(43,79,53,79,58,98,45,92,39,99),ink)
            if machine { shape(path(34,35,62,35,69,58,61,83,35,83,27,58)) } else { oval(29,33,67,86) }
            box(37,43,59,64,trim,radius:5,outline:false)
            if kind == "CAMEL" { oval(39,45,57,68,body,outline:false) }
            shape(path(36,11,42,18,48,14,54,18,60,11,58,30,56,41,40,41,38,30))
            oval(39,22,57,40,machine ? trim : body,outline:false); line(42,28,54,28,ink)
            if kind == "HORNED_STEED" { line(39,20,31,9,light,5); line(57,20,65,9,light,5) }
            if machine { line(28,56,38,56,trim,4); line(58,56,68,56,trim,4) }
        }
        func minecart() {
            for x: CGFloat in [19,68] { for y: CGFloat in [29,70] { box(x,y,x+9,y+13,ink) } }
            shape(path(22,25,35,12,64,12,76,25,72,88,26,88)); box(29,27,67,71,ink); box(35,32,61,58,trim,outline:false)
            box(25,73,73,87); line(31,78,65,78,light); line(35,19,61,19,light,4)
        }
        func pig() {
            let pink = UIColor(hex:"E4979F")
            for x: CGFloat in [24,59] { for y: CGFloat in [42,74] { box(x,y,x+13,y+13,UIColor(hex:"A35C71")) } }
            box(27,36,69,87,pink,radius:7); box(28,15,39,30,pink); box(57,15,68,30,pink); box(31,20,65,46,pink,radius:4)
            box(38,21,58,31,UIColor(hex:"F2B6B1"),outline:false); box(39,33,43,37,ink,outline:false); box(53,33,57,37,ink,outline:false)
            box(35,51,61,68,UIColor(hex:"7D4F30"),outline:false); line(44,88,53,94,pink,5)
        }
        func boat(_ sails: Bool) {
            let p = UIBezierPath(); p.move(to: CGPoint(x:48,y:7)); p.addCurve(to: CGPoint(x:64,y:94),controlPoint1:CGPoint(x:81,y:35),controlPoint2:CGPoint(x:78,y:75)); p.addLine(to:CGPoint(x:32,y:94)); p.addCurve(to:CGPoint(x:48,y:7),controlPoint1:CGPoint(x:18,y:75),controlPoint2:CGPoint(x:15,y:35)); p.close(); shape(p)
            shape(path(48,23,65,45,62,81,34,81,31,45),trim,outline:false)
            for y: CGFloat in [49,65,81] { line(31,y,65,y,body,4) }
            if sails { line(48,19,48,87,ink,4); shape(path(24,35,69,35,61,61,29,61),light); line(47,36,47,59,body,2) }
            else { line(14,77,35,43,ink,7); line(14,77,35,43,light); line(82,77,61,43,ink,7); line(82,77,61,43,light) }
        }
        func carriage() {
            for x: CGFloat in [18,67] { for y: CGFloat in [29,67] { box(x,y,x+11,y+22,ink,radius:5) } }
            line(39,11,39,32,trim,6); line(57,11,57,32,trim,6); box(27,27,69,91,radius:10)
            box(31,35,65,70,trim,radius:9,outline:false); line(32,42,64,42,body); line(32,62,64,62,body); box(35,79,61,86,ink,radius:2,outline:false)
        }
        func machine(_ wings: Bool) {
            if wings { shape(path(35,34,9,49,9,70,34,61)); shape(path(61,34,87,49,87,70,62,61)); box(24,65,38,91,trim,radius:2); box(58,65,72,91,trim,radius:2) }
            else { line(25,46,17,74,light,7); line(71,46,79,74,light,7); box(14,71,24,82,trim,radius:2); box(72,71,82,82,trim,radius:2) }
            shape(path(36,13,60,13,65,30,63,69,33,69,31,30)); box(38,22,58,30,ink,outline:false); line(39,25,57,25,trim,2)
            box(40,43,56,57,trim,outline:false); line(40,75,40,88,ink,5); line(56,75,56,88,ink,5)
        }
        func bicycle() {
            box(44,8,52,33,ink,radius:4); box(44,73,52,98,ink,radius:4)
            line(48,25,48,82,light,9); line(48,25,48,82,body,5); line(48,34,32,61,light,8); line(32,61,48,77,light,8)
            line(48,34,32,61,body,4); line(32,61,48,77,body,4); box(30,28,66,34,trim,radius:3); box(37,56,59,64,radius:4)
            line(32,67,64,67,ink,4); box(25,64,35,70,trim,radius:1); box(61,64,71,70,trim,radius:1)
        }
        func broom() {
            shape(path(45,8,53,8,52,67,42,67),trim); shape(path(39,58,58,58,70,93,57,90,47,98,37,91,25,95))
            line(37,67,60,67,trim,5); line(44,73,39,89,trim,2); line(51,73,54,88,trim,2)
        }
    }
}
