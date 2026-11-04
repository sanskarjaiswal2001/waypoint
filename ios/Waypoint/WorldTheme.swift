import CoreText
import SwiftUI

/// The phone palette and typography shared with the Android world HUDs.
struct WorldTheme {
    let panelHex: String
    let foregroundHex: String
    let accentHex: String
    let mutedHex: String
    var panel: Color { Color(hex: panelHex).opacity(0.96) }
    var foreground: Color { Color(hex: foregroundHex) }
    var accent: Color { Color(hex: accentHex) }
    var muted: Color { Color(hex: mutedHex) }
}

enum SharedArt {
    static let names: [String: String] = {
        guard let url = Bundle.main.url(forResource: "font-names", withExtension: "json"),
              let data = try? Data(contentsOf: url), let names = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return names
    }()
    static func install() {
        for name in names.keys {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "otf", subdirectory: "fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
    static func font(_ file: String, _ size: CGFloat) -> Font { .custom(names[file] ?? "Helvetica", size: size, relativeTo: .body) }
    private static let images = NSCache<NSString, UIImage>()
    static func image(_ name: String) -> UIImage? {
        if let image = images.object(forKey: name as NSString) { return image }
        for ext in ["png", "jpg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "ui"), let image = UIImage(contentsOfFile: url.path) {
                images.setObject(image, forKey: name as NSString)
                return image
            }
        }
        return nil
    }
}

extension World {
    var theme: WorldTheme {
        let values: [String]
        switch id {
        case "assassin": values = ["20282A", "F4EDDB", "EBD28C", "CBC8B7"]
        case "far_cry": values = ["17231F", "F5F4E8", "F4D57B", "C3CBBD"]
        case "ghost": values = ["202520", "F2EEE1", "F2EEE1", "C5C9BD"]
        case "bridges": values = ["142733", "C4F1EC", "9AE5DD", "A4C0C9"]
        case "horizon_wilds": values = ["27251F", "F5ECD7", "F0DBAC", "CCC2AA"]
        case "spider": values = ["152B3B", "D5F2F5", "FFB1AA", "A7CAD5"]
        case "hogwarts": values = ["1C2734", "F1E4C9", "E5CE93", "C4BDAC"]
        case "starfield": values = ["203144", "EFF2EE", "F0D3A1", "BDCBD1"]
        case "kingdom": values = ["2C2820", "F0E2BD", "E6CF94", "CCBEA0"]
        case "saints": values = ["221C32", "F2EAFA", "D0A6FB", "C5B7D3"]
        case "just_cause": values = ["162F3E", "D4F1EF", "87ECDF", "B1CCD0"]
        case "mafia": values = ["232621", "F4E8CE", "E8D29A", "C9C6B1"]
        case "vice_coast": values = ["1E1D29", "FFD3EA", "FFAFE1", "D2CDD4"]
        case "liberty": values = ["16181A", "F1F1EE", "FFD06D", "B9C0C2"]
        case "ctos": values = ["F8F9F3", "18272D", "185D89", "42545B"]
        case "hyrule": values = ["0B1C29", "9DDBF8", "F0D18B", "AAC9D7"]
        case "skyrim": values = ["12191E", "E5EFF1", "ECF3F4", "B8C9D0"]
        case "lands_between": values = ["2A2922", "F1E5C7", "E3CC8D", "CBC1A5"]
        case "horizon": values = ["FEFCFC", "2D2430", "9D0062", "625361"]
        case "old_west", "rivia": values = ["1D1A16", "F5EAD4", "F5EAD4", "CEC0A8"]
        case "night_city": values = ["0D1720", "8FF6ED", "F5E95C", "9FBFC3"]
        case "green_terminal": values = ["07180D", "A4F780", "A4F780", "91C77C"]
        case "pixel": values = ["2B2B29", "F3F1E7", "ACED75", "CECEBF"]
        case "heat": values = ["191427", "FFF0FB", "9CF5F7", "D7B6D4"]
        default: values = ["191B1B", "F5F5F0", "B6DB91", "C0C5BF"]
        }
        return WorldTheme(panelHex: values[0], foregroundHex: values[1], accentHex: values[2], mutedHex: values[3])
    }
    var inspiration: String {
        let names = ["los_santos":"Grand Theft Auto V", "old_west":"Red Dead Redemption 2", "night_city":"Cyberpunk 2077", "pixel":"Minecraft", "green_terminal":"Fallout · Pip-Boy", "san_andreas":"GTA: San Andreas", "heat":"Need for Speed", "rivia":"The Witcher 3", "vice_coast":"GTA: Vice City", "liberty":"Grand Theft Auto IV", "ctos":"Watch Dogs 2", "hyrule":"Zelda: Breath of the Wild", "skyrim":"The Elder Scrolls V", "lands_between":"Elden Ring", "horizon":"Forza Horizon 5", "assassin":"Assassin’s Creed Origins", "far_cry":"Far Cry 5", "ghost":"Ghost of Tsushima", "bridges":"Death Stranding", "horizon_wilds":"Horizon Zero Dawn", "spider":"Marvel’s Spider-Man", "hogwarts":"Hogwarts Legacy", "starfield":"Starfield", "kingdom":"Kingdom Come: Deliverance II", "saints":"Saints Row: The Third", "just_cause":"Just Cause 3", "mafia":"Mafia: Definitive Edition"]
        return names[id] ?? subtitle
    }
    var titleFontFile: String {
        switch id {
        case "vice_coast": return "yellowtail"
        case "los_santos", "san_andreas", "liberty": return "pricedown_black"
        case "lands_between", "hyrule", "assassin", "horizon_wilds", "hogwarts", "kingdom", "mafia": return "cinzel"
        case "old_west": return "chinese_rocks_regular"
        case "rivia": return "libre_baskerville"
        case "pixel": return "monocraft"
        case "green_terminal": return "share_tech_mono"
        case "night_city", "bridges", "spider", "starfield": return "rajdhani"
        default: return "barlow_condensed_bold"
        }
    }
    var hudFontFile: String {
        switch id {
        case "old_west": return "kirsty_regular"
        case "pixel": return "monocraft"
        case "green_terminal": return "roboto_condensed"
        case "night_city", "bridges", "spider", "starfield": return "rajdhani"
        case "lands_between", "rivia", "kingdom", "hogwarts", "mafia": return "libre_baskerville"
        case "ctos", "horizon", "saints": return "noto_sans"
        default: return "barlow_condensed_bold"
        }
    }
    func font(_ size: CGFloat, title: Bool = false) -> Font { SharedArt.font(title ? titleFontFile : hudFontFile, size) }
    var artZoom: Double { ["los_santos":16.2,"old_west":16,"night_city":16.2,"pixel":17,"green_terminal":16.1,"san_andreas":16,"heat":15.8,"rivia":15.6,"vice_coast":16,"liberty":16.1,"ctos":16,"hyrule":15.7,"skyrim":15.5,"lands_between":15.6,"horizon":15.9,"assassin":15.6,"far_cry":15.7,"ghost":15.6,"bridges":15.7,"horizon_wilds":15.6,"spider":16.1,"hogwarts":15.5,"starfield":15.9,"kingdom":15.6,"saints":16,"just_cause":15.6,"mafia":16][id] ?? 16 }
    var artTilt: Double { ["night_city":45,"pixel":42,"skyrim":35,"far_cry":30,"bridges":25,"spider":40,"hogwarts":25,"starfield":30][id] ?? 45 }
    var defaultTilted: Bool { ["night_city","pixel","skyrim","far_cry","bridges","spider","hogwarts","starfield"].contains(id) }
    var routeWidth: Double { ["los_santos":5,"old_west":3.8,"night_city":3.8,"pixel":5,"green_terminal":3,"san_andreas":5,"heat":4.5,"rivia":3,"vice_coast":5,"liberty":4.5,"ctos":4,"hyrule":2.5,"skyrim":2,"lands_between":2.5,"horizon":4.5,"assassin":2.5,"far_cry":3.5,"ghost":2.5,"bridges":2.5,"horizon_wilds":3,"spider":4,"hogwarts":2.5,"starfield":2.5,"kingdom":3,"saints":4,"just_cause":3,"mafia":4][id] ?? 3 }
    var hudBorder: Color? {
        switch id {
        case "hogwarts", "kingdom", "assassin": return Color(hex: "9D8A5F")
        case "bridges", "starfield": return Color(hex: "698E9F")
        case "hyrule": return Color(hex: "A9935B")
        case "lands_between": return Color(hex: "93876A")
        case "skyrim": return Color(hex: "829298")
        case "night_city": return Color(hex: "965150")
        case "green_terminal": return Color(hex: "6BAD59")
        case "pixel": return Color(hex: "92968A")
        default: return nil
        }
    }
}

struct AtlasShape: Shape {
    var cut: CGFloat = 0
    var round: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        if round > 0 { return Path(roundedRect: rect, cornerRadius: round) }
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut)); p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut)); p.closeSubpath()
        return p
    }
}

extension View {
    func atlasPanel(_ world: World) -> some View {
        let shape = AtlasShape(cut: ["night_city","heat","spider"].contains(world.id) ? 10 : 0, round: ["ctos","horizon","old_west","rivia"].contains(world.id) ? 3 : 0)
        return foregroundStyle(world.theme.foreground).background(world.theme.panel).clipShape(shape)
            .overlay(shape.stroke(world.hudBorder ?? .clear, lineWidth: world.id == "pixel" ? 2 : 1))
    }
}
