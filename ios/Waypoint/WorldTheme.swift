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
        case "nier": values = ["D8D4BC", "35362E", "793D2B", "5D5C4D"]
        case "stalker": values = ["212624", "E9E9DE", "E6C274", "B8BDB0"]
        case "division": values = ["1A2B2D", "F2F4EA", "FFAE61", "B8CCC7"]
        case "sea_chart": values = ["E9DAB4", "302D24", "7C352C", "625642"]
        case "dos_atlas": values = ["1D160F", "FFDF9B", "FFCF80", "D2B58A"]
        case "aincrad": values = ["FCFAEE", "383B3B", "8E531A", "68614D"]
        case "counter_strike": values = ["282927", "F2F0E5", "FFD37F", "BFC3BB"]
        case "defcon": values = ["051026", "D9E9FF", "9AC8FF", "A5BBD6"]
        case "field_ops": values = ["252D25", "F0F2E8", "CDDCAC", "BCC7B0"]
        case "retro_quest": values = ["32284A", "FFF1CF", "FFE0A0", "D6C5DF"]
        case "home_console": values = ["F7FBFD", "203E4B", "12678C", "4A6472"]
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
        let additions = ["division":"Tom Clancy’s The Division", "sea_chart":"Sea of Thieves", "dos_atlas":"DOS / ASCII interfaces", "aincrad":"Sword Art Online", "counter_strike":"Counter-Strike", "defcon":"DEFCON", "field_ops":"Call of Duty: Modern Warfare", "retro_quest":"16-bit console adventures", "home_console":"Wii U console interface", "stalker":"S.T.A.L.K.E.R.: Shadow of Chernobyl", "nier":"NieR:Automata"]
        return names[id] ?? additions[id] ?? subtitle
    }
    var titleFontFile: String {
        if let titleTypeface { return titleTypeface }
        switch id {
        case "division": return "borda_bold"
        case "counter_strike": return "stratum2_bold"
        case "sea_chart": return "windlass"
        case "skyrim": return "futura_condensed_medium"
        case "field_ops": return "rajdhani"
        case "dos_atlas", "defcon": return "share_tech_mono"
        case "retro_quest": return "monocraft"
        case "aincrad", "home_console", "nier": return "noto_sans"
        case "stalker": return "roboto_condensed"
        case "vice_coast": return "yellowtail"
        case "los_santos", "san_andreas", "liberty": return "pricedown_black"
        case "lands_between", "hyrule", "assassin", "horizon_wilds", "hogwarts", "kingdom", "mafia": return "cinzel"
        case "old_west": return "chinese_rocks_regular"
        case "rivia": return "libre_baskerville"
        case "pixel": return "minecraft_seven"
        case "green_terminal": return "share_tech_mono"
        case "night_city", "bridges", "spider", "starfield": return "rajdhani"
        default: return "barlow_condensed_bold"
        }
    }
    var hudFontFile: String {
        if let readingTypeface { return readingTypeface }
        switch id {
        case "division": return "borda_regular"
        case "counter_strike": return "stratum2_regular"
        case "sea_chart": return "libre_baskerville"
        case "skyrim": return "futura_condensed_medium"
        case "field_ops": return "rajdhani"
        case "dos_atlas", "defcon": return "share_tech_mono"
        case "retro_quest": return "monocraft"
        case "aincrad", "home_console", "nier": return "noto_sans"
        case "stalker": return "roboto_condensed"
        case "old_west": return "kirsty_regular"
        case "pixel": return "minecraft_seven"
        case "green_terminal": return "roboto_condensed"
        case "night_city", "bridges", "spider", "starfield": return "rajdhani"
        case "lands_between", "rivia", "kingdom", "hogwarts", "mafia": return "libre_baskerville"
        case "ctos", "horizon", "saints": return "noto_sans"
        default: return "barlow_condensed_bold"
        }
    }
    func font(_ size: CGFloat, title: Bool = false) -> Font { SharedArt.font(title ? titleFontFile : hudFontFile, size) }
    var lightInterface: Bool { ["ctos", "horizon", "sea_chart", "aincrad", "home_console", "nier"].contains(id) }
    var artZoom: Double { mapArt?.zoom ?? 16 }
    var artTilt: Double { let tilt = mapArt?.tilt ?? 0; return tilt > 0 ? tilt : 45 }
    var defaultTilted: Bool { (mapArt?.tilt ?? 0) > 0 }
    var routeWidth: Double { mapArt?.routeWidth ?? 3 }
    var hudBorder: Color? {
        switch id {
        case "division": return Color(hex: "9E7651")
        case "sea_chart", "aincrad": return Color(hex: "8C7956")
        case "dos_atlas", "retro_quest": return theme.accent
        case "counter_strike", "field_ops": return theme.muted
        case "defcon": return theme.accent
        case "stalker": return Color(hex: "879080")
        case "nier": return theme.muted
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
    var reverseCut = false
    var allCorners = false
    func path(in rect: CGRect) -> Path {
        if round > 0 { return Path(roundedRect: rect, cornerRadius: round) }
        var p = Path()
        if allCorners {
            p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut)); p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut)); p.closeSubpath()
            return p
        }
        p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut)); p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut)); p.closeSubpath()
        return reverseCut ? p.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0)) : p
    }
}

extension World {
    var panelShape: AtlasShape {
        let cut: CGFloat = ["night_city", "heat", "spider"].contains(id) ? 10 : ["division", "field_ops"].contains(id) ? 8 : id == "stalker" ? 4 : 0
        let round: CGFloat = id == "home_console" ? 12 : id == "aincrad" ? 4 : ["ctos", "horizon", "old_west", "rivia"].contains(id) ? 3 : 0
        return AtlasShape(cut: cut, round: round, reverseCut: ["division", "field_ops"].contains(id), allCorners: id == "stalker")
    }
}

extension View {
    func atlasPanel(_ world: World) -> some View {
        let shape = world.panelShape
        return foregroundStyle(world.theme.foreground).background(world.theme.panel).clipShape(shape)
            .overlay(shape.stroke(world.hudBorder ?? .clear, lineWidth: world.id == "pixel" ? 2 : 1))
    }
}
