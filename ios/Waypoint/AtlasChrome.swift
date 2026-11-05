import SwiftUI

struct AtlasActions {
    let search: (String) -> Void
    let worlds: () -> Void
    let saved: () -> Void
    let settings: () -> Void
    let quests: () -> Void
}

struct AtlasChrome: View {
    let model: NavigationModel
    let actions: AtlasActions
    private var w: World { model.world }
    private var p: WorldTheme { w.theme }

    var body: some View {
        GeometryReader { size in
            ZStack {
                if size.size.height < 420 { compact }
                else { composition }
                if !["los_santos","night_city","horizon","hogwarts","bridges","far_cry"].contains(w.id) || size.size.height < 420 {
                    tool("Map tilt", "view.3d", action: { model.tilted.toggle() }).placed(.trailing)
                }
            }.padding(12)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: actions.quests) { Label("Quests", systemImage: "checklist").font(w.font(16)).frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(.plain).atlasPanel(w).padding(.horizontal, 12)
            }
        }
    }

    @ViewBuilder private var composition: some View {
        switch w.id {
        case "los_santos": losSantos
        case "old_west": western
        case "night_city": nightCity
        case "pixel": pixel
        case "green_terminal": terminal
        case "san_andreas": sanAndreas
        case "vice_coast": vice
        case "liberty": liberty
        case "ctos": nudle
        case "heat": heat
        case "horizon": forza
        case "rivia": witcher
        case "hyrule": sheikah
        case "skyrim": skyrim
        case "lands_between": elden
        case "assassin": animus
        case "ghost": ghost
        case "horizon_wilds": embrace
        case "hogwarts": hogwarts
        case "kingdom": bohemia
        case "far_cry": farCry
        case "bridges": bridges
        case "spider": spider
        case "starfield": starfield
        case "saints": saints
        case "just_cause": medici
        case "mafia": mafia
        case "division": division
        case "sea_chart": seaChart
        case "dos_atlas": dosAtlas
        case "aincrad": aincrad
        case "counter_strike": tacticalRadar
        case "defcon": vectorCommand
        case "field_ops": fieldOps
        case "retro_quest": retroQuest
        case "home_console": homeConsole
        case "stalker": stalker
        case "nier": machineAtlas
        default: compact
        }
    }
    private var newWorldMenu: some View { HStack { worlds; saved; settings }.atlasPanel(w) }
    private var division: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) { VStack(alignment: .leading) { Label(w.title, systemImage: "location.north.circle").font(w.font(26, title: true)).foregroundStyle(p.accent); text(model.city, 16); text(model.fixLabel, 12) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).atlasPanel(w); find() }.placed(.top)
            VStack(alignment: .leading) { fix; newWorldMenu }.placed(.bottomLeading)
            VStack { compass; locate }.placed(.bottomTrailing)
        }
    }
    private var seaChart: some View {
        ZStack {
            VStack { text(w.title, 26, title: true).padding(14).atlasPanel(w); city; find("Where shall we go?") }.placed(.top)
            VStack { compass; locate }.placed(.bottomLeading)
            VStack { worlds; saved; settings }.placed(.bottomTrailing)
        }
    }
    private var dosAtlas: some View {
        ZStack {
            VStack(alignment: .leading) { text("WAYPOINT / DOS ATLAS", 22); Divider().overlay(p.accent); city; find("Find a place") }.padding(12).atlasPanel(w).placed(.top)
            VStack { fix; HStack { worlds; saved }; HStack { locate; settings } }.padding(10).frame(maxWidth: .infinity).atlasPanel(w).placed(.bottom)
        }
    }
    private var aincrad: some View {
        ZStack {
            VStack { HStack { VStack(alignment: .leading) { text(w.title, 24, title: true); text(model.city, 14); fix }; Spacer(); Image(systemName: "location.north.circle").font(.largeTitle) }.padding(14).atlasPanel(w); find() }.placed(.top)
            VStack { worlds; saved; settings }.placed(.bottomLeading)
            VStack { compass; locate }.placed(.bottomTrailing)
        }
    }
    private var tacticalRadar: some View {
        ZStack {
            HStack { compass; VStack(alignment: .leading) { text(w.title, 20, color: p.accent); text(model.city, 14) }.padding(12).frame(maxWidth: .infinity).atlasPanel(w) }.placed(.top)
            VStack { find(); HStack { worlds; saved; settings; locate }.frame(maxWidth: .infinity).atlasPanel(w); fix }.placed(.bottom)
        }
    }
    private var vectorCommand: some View {
        ZStack {
            VStack(alignment: .leading) { text(w.title, 24); text(model.city, 14); Divider().overlay(p.accent); fix }.padding(12).frame(maxWidth: .infinity, alignment: .leading).atlasPanel(w).placed(.top)
            VStack { find("Set a destination"); HStack { worlds; saved; locate; settings }.frame(maxWidth: .infinity).atlasPanel(w) }.placed(.bottom)
        }
    }
    private var fieldOps: some View {
        ZStack {
            VStack { HStack { VStack(alignment: .leading) { text(w.title, 26); text(model.city, 14) }.padding(12).frame(maxWidth: .infinity).atlasPanel(w); compass }; find("Choose your destination") }.placed(.top)
            VStack(alignment: .leading) { fix; newWorldMenu }.placed(.bottomLeading)
            locate.placed(.bottomTrailing)
        }
    }
    private var retroQuest: some View {
        ZStack {
            VStack { text(w.title, 24); text(model.city, 14); fix; find("Find a place") }.padding(14).atlasPanel(w).placed(.top)
            VStack { HStack { worlds; saved }; HStack { locate; settings } }.padding(10).frame(maxWidth: .infinity).atlasPanel(w).placed(.bottom)
        }
    }
    private var homeConsole: some View {
        ZStack {
            VStack { VStack(alignment: .leading) { text("Where next?", 26); text(model.city, 16) }.padding(18).frame(maxWidth: .infinity, alignment: .leading).atlasPanel(w); find() }.placed(.top)
            VStack { HStack { worlds; saved; settings; locate }; fix }.padding(8).frame(maxWidth: .infinity).atlasPanel(w).placed(.bottom)
        }
    }
    private var stalker: some View {
        ZStack {
            Rectangle().stroke(Color(hex: "879080"), lineWidth: 5).padding(4).allowsHitTesting(false)
            VStack { HStack { Image(systemName: "map").font(.largeTitle); VStack(alignment: .leading) { text(w.title, 24); text(model.city, 15) } }.padding(12).frame(maxWidth: .infinity).atlasPanel(w); find("Find a place") }.placed(.top)
            VStack(alignment: .leading) { fix; newWorldMenu }.placed(.bottomLeading)
            VStack { compass; locate }.placed(.bottomTrailing)
        }
    }
    private var machineAtlas: some View {
        ZStack {
            VStack { VStack(alignment: .leading) { HStack { Image(systemName: "map"); text(w.title, 24) }; text(model.city, 15); VStack(spacing: 3) { ForEach(0..<3) { _ in Divider().overlay(p.muted) } } }.padding(14).frame(maxWidth: .infinity).atlasPanel(w); find("Find a place") }.placed(.top)
            VStack(alignment: .leading) { fix; newWorldMenu }.placed(.bottomLeading)
            VStack { compass; locate }.placed(.bottomTrailing)
        }
    }
    private func text(_ value: String, _ size: CGFloat = 18, color: Color? = nil, title: Bool = false) -> some View {
        Text(value).font(w.font(size, title: title)).foregroundStyle(color ?? p.foreground).lineLimit(1).minimumScaleFactor(0.7)
    }
    private var city: some View { text(model.city, 20).padding(.horizontal, 12).padding(.vertical, 7).atlasPanel(w) }
    private var fix: some View { text(model.fixLabel, 12).padding(7).atlasPanel(w).accessibilityLabel(model.fixLabel) }
    private func tool(_ title: String, _ icon: String, light: Bool = false, round: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 21)).frame(width: 46, height: 46)
                    .foregroundStyle(light ? Color(hex: p.panelHex) : p.foreground)
                    .background(light ? p.foreground : p.panel)
                    .clipShape(round ? AnyAtlasShape.circle : AnyAtlasShape.panel(w))
                    .overlay((round ? AnyAtlasShape.circle : AnyAtlasShape.panel(w)).stroke(round ? p.foreground : (w.hudBorder ?? .clear), lineWidth: 1))
                Text(title).font(SharedArt.font("roboto_condensed", 12)).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity).padding(.vertical, 2).atlasPanel(w)
            }.frame(width: 58).foregroundStyle(p.foreground)
        }.buttonStyle(.plain).accessibilityLabel(title == "Search" ? "Search places" : title)
    }
    private var locate: some View { tool("Locate", "location.viewfinder", round: ["old_west","rivia","lands_between"].contains(w.id), action: model.locate) }
    private var search: some View { tool("Search", "magnifyingglass", action: { actions.search("") }) }
    private var worlds: some View { tool("Worlds", "square.3.layers.3d", action: actions.worlds) }
    private var saved: some View { tool("Saved", "bookmark", action: actions.saved) }
    private var settings: some View { tool("Settings", "slider.horizontal.3", action: actions.settings) }
    private var tilt: some View { tool("Map tilt", "view.3d", action: { model.tilted.toggle() }) }
    private func action(_ title: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) { text(title, 16).padding(.horizontal, 14).frame(minHeight: 46) }
            .buttonStyle(.plain).atlasPanel(w)
            .accessibilityLabel(title == "Search places" || title == "Set a destination" || title == "FIND LOCATION" ? "Search places" : title)
    }
    private func find(_ title: String = "Search places") -> some View {
        Button { actions.search("") } label: {
            HStack { Image(systemName: "magnifyingglass"); text(title, 18); Spacer(minLength: 2); Image(systemName: "chevron.right") }
                .padding(14).frame(minHeight: 52)
        }.buttonStyle(.plain).atlasPanel(w).accessibilityLabel("Search places")
    }
    private var tabs: some View {
        HStack(spacing: 0) {
            action("MAP", model.locate).background(p.foreground.opacity(0.15))
            action("Worlds", actions.worlds).frame(maxWidth: .infinity)
            action("Saved", actions.saved).frame(maxWidth: .infinity)
            settings
        }.atlasPanel(w)
    }
    private var compass: some View { AtlasCompass(bearing: model.bearing, world: w, ornate: ["old_west","ghost","lands_between","kingdom","hogwarts"].contains(w.id), action: model.locate) }
    private var frame: some View {
        Canvas { context, size in
            let c = p.accent.opacity(0.6)
            if ["hyrule","hogwarts","kingdom","lands_between"].contains(w.id) {
                context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(c), lineWidth: 1)
                for x in [CGFloat(0), size.width] { for y in [CGFloat(0), size.height] {
                    let sx: CGFloat = x < size.width / 2 ? 1 : -1
                    let sy: CGFloat = y < size.height / 2 ? 1 : -1
                    var path = Path(); path.move(to: CGPoint(x: x, y: y + 22 * sy)); path.addLine(to: CGPoint(x: x + 22 * sx, y: y))
                    context.stroke(path, with: .color(c), lineWidth: 2)
                    context.stroke(Path(ellipseIn: CGRect(x: x + 8 * sx - 3, y: y + 8 * sy - 3, width: 6, height: 6)), with: .color(c), lineWidth: 1)
                } }
            } else {
                let ink = ["night_city","spider"].contains(w.id) ? Color(hex: "D44B50") : c
                var path = Path()
                for y in [CGFloat(0), size.height] { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)) }
                context.stroke(path, with: .color(ink), lineWidth: 1)
                for x in [CGFloat(0), size.width] {
                    var corners = Path(); corners.move(to: CGPoint(x: x, y: 0)); corners.addLine(to: CGPoint(x: x, y: 50)); corners.move(to: CGPoint(x: x, y: size.height - 50)); corners.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(corners, with: .color(ink), lineWidth: 2)
                }
                if w.id == "starfield" {
                    for x in stride(from: CGFloat(0), to: size.width, by: 14) { for y in stride(from: CGFloat(0), to: size.height, by: 14) { context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(c.opacity(0.14))) } }
                }
            }
        }.padding(-4).allowsHitTesting(false)
    }
    private var allTools: some View { HStack(spacing: 1) { search; locate; saved; worlds; settings }.frame(maxWidth: .infinity) }
    private var statusBars: some View {
        HStack(spacing: 4) {
            bar("GPS", ready: model.hasFreshFix, color: p.accent)
            bar("ROUTE", ready: model.route != nil, color: Color(hex: "789AA8"))
            bar("VOICE", ready: model.voiceEnabled, color: Color(hex: "E8CD75"))
        }.padding(8).atlasPanel(w)
    }
    private func bar(_ label: String, ready: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9)).foregroundStyle(p.muted)
            Rectangle().fill(color.opacity(ready ? 1 : 0.25)).frame(height: 4)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(label): \(ready ? "ready" : "inactive")")
    }
    private var losSantos: some View {
        ZStack {
            VStack { HStack { text(model.city, 25); Spacer(); search }; tabs }.placed(.top)
            VStack(alignment: .trailing, spacing: 1) { nearby("Food", "fork.knife"); nearby("Fuel", "fuelpump"); nearby("Parking", "parkingsign"); tilt }.placed(.trailing)
            HStack(alignment: .bottom) { VStack(alignment: .leading, spacing: 0) { fix; statusBars }; Spacer(); tool("Locate", "location.viewfinder", light: true, action: model.locate) }.placed(.bottom)
        }
    }
    private func nearby(_ title: String, _ icon: String) -> some View {
        Button { actions.search(title) } label: { HStack { Text(title).font(.system(size: 12)); Image(systemName: icon) }.padding(12).frame(minHeight: 44) }
            .buttonStyle(.plain).atlasPanel(w).accessibilityLabel("Find \(title.lowercased())")
    }
    private var western: some View {
        ZStack {
            VStack(spacing: 2) { text(model.city.uppercased(), 21).padding(.horizontal, 20).padding(.vertical, 10).atlasPanel(w); Rectangle().fill(p.accent).frame(width: 120, height: 2) }.placed(.top)
            tool("Search", "magnifyingglass", round: true, action: { actions.search("") }).padding(.top, 70).placed(.topTrailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) { locate; tool("Saved", "bookmark", round: true, action: actions.saved); tool("Worlds", "square.3.layers.3d", round: true, action: actions.worlds) }
                HStack(alignment: .bottom) { compass; VStack(alignment: .leading) { fix; action("Settings", actions.settings) } }
            }.placed(.bottomLeading)
        }
    }
    private var nightCity: some View {
        ZStack {
            frame
            VStack(alignment: .leading, spacing: 4) { HStack { text("MAP", 32, color: Color(hex: "FF656A")); Spacer(); search; settings }; Rectangle().fill(Color(hex: "CC3D49")).frame(height: 1); text(model.city.uppercased(), 18) }.padding(5).placed(.top)
            VStack(alignment: .trailing, spacing: 7) { text("DESTINATIONS", 12, color: p.accent); action("FIND LOCATION", { actions.search("") }); action("SAVED PLACES", actions.saved) }.placed(.trailing)
            VStack(alignment: .leading) { fix; HStack { action("Worlds", actions.worlds); Spacer(); action("RECENTER", model.locate); tilt } }.placed(.bottom)
        }
    }
    private var pixel: some View {
        ZStack {
            VStack(alignment: .leading) { text(model.city, 14); text(model.coordinate.map { String(format: "%.4f, %.4f", $0.latitude, $0.longitude) } ?? "Map preview", 11) }.padding(8).atlasPanel(w).placed(.topLeading)
            VStack(spacing: 8) { fix; Rectangle().fill(p.accent.opacity(model.hasFreshFix ? 1 : 0.2)).frame(maxWidth: 260).frame(height: 5); HStack(spacing: 1) {
                pixelSlot("Search", "pixel_search", { actions.search("") }); pixelSlot("Locate", "pixel_locate", model.locate); pixelSlot("Worlds", "pixel_huds", actions.worlds); pixelSlot("Saved", "pixel_saved", actions.saved); pixelSlot("Settings", "pixel_settings", actions.settings)
            }.padding(3).background(Color(hex: "141613")) }.placed(.bottom)
        }
    }
    private func pixelSlot(_ title: String, _ asset: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) { VStack(spacing: 3) {
            Group { if let image = SharedArt.image(asset) { Image(uiImage: image).resizable().interpolation(.none).scaledToFit() } else { Image(systemName: "square") } }
                .frame(width: 28, height: 28).padding(10).background(Color(hex: "565653")).border(Color(hex: "B5B5AC"), width: 2)
            Text(title).font(SharedArt.font("roboto_condensed", 12)).foregroundStyle(.white)
        }.frame(width: 54) }.buttonStyle(.plain).accessibilityLabel(title == "Search" ? "Search places" : title)
    }
    private var terminal: some View {
        ZStack {
            VStack(alignment: .leading) { tabs; Divider().overlay(p.accent); HStack { text("LOCAL MAP", 20); Spacer(); search } }.placed(.top)
            VStack(alignment: .leading) { HStack { text(model.city.uppercased(), 18); Spacer(); locate }; Divider().overlay(p.accent); fix }.placed(.bottom)
        }
    }
    private var sanAndreas: some View {
        ZStack {
            VStack(alignment: .leading) { Text("Map").font(SharedArt.font("kirsty_regular", 42)).foregroundStyle(Color(hex: "1D241C")); HStack { action("Worlds", actions.worlds); action("Saved", actions.saved); settings } }.placed(.topLeading)
            compass.placed(.topTrailing)
            VStack(alignment: .leading) { city; HStack { find(); locate } }.placed(.bottom)
        }
    }
    private var vice: some View {
        ZStack {
            VStack(alignment: .leading) { text("Map", 44, color: Color(hex: "6B184E"), title: true); city }.placed(.topLeading)
            VStack { worlds; settings }.placed(.topTrailing)
            HStack(alignment: .bottom) { compass; VStack { find(); HStack { action("Saved", actions.saved); action("Locate", model.locate) } } }.placed(.bottom)
        }
    }
    private var liberty: some View {
        ZStack { VStack(alignment: .leading) { tabs; city }.placed(.top); VStack(alignment: .trailing) { action("Set a destination", { actions.search("") }); action("Center on player", model.locate); fix }.placed(.bottomTrailing) }
    }
    private var nudle: some View {
        ZStack {
            VStack { HStack { text("nudle", 30, color: Color(hex: "236AAD")); Spacer(); worlds; settings }.padding(.leading, 12).atlasPanel(w); find() }.placed(.top)
            VStack { nearby("Food", "fork.knife"); nearby("Fuel", "fuelpump"); saved }.placed(.leading)
            HStack(alignment: .bottom) { VStack(alignment: .leading) { city; fix }; Spacer(); locate }.placed(.bottom)
        }
    }
    private var heat: some View {
        ZStack { VStack(alignment: .leading) { text("NIGHT / MAP", 28, color: Color(hex: "EC72C8")); text(model.city, 16); HStack { action("Worlds", actions.worlds); action("Saved", actions.saved); settings } }.placed(.topLeading)
            VStack(alignment: .trailing) { action("SET ROUTE", { actions.search("") }); HStack { fix; locate } }.placed(.bottomTrailing) }
    }
    private var forza: some View {
        ZStack { VStack(alignment: .leading) { HStack { action("WORLD MAP", { actions.search("") }); Spacer(); worlds; settings }.atlasPanel(w); city }.placed(.top)
            VStack { saved; tilt }.placed(.leading); HStack { find("Find a place"); locate }.placed(.bottom) }
    }
    private var witcher: some View {
        ZStack { VStack(spacing: 2) { HStack { worlds; text("WORLD MAP", 19); Spacer(); settings }; Divider().overlay(p.accent); city }.atlasPanel(w).placed(.top)
            VStack(alignment: .leading) { compass; action("Saved places", actions.saved); find().frame(maxWidth: 248) }.placed(.bottomLeading); locate.placed(.bottomTrailing) }
    }
    private var sheikah: some View {
        ZStack { frame; VStack(spacing: 2) { ornament; HStack { worlds; text("Map", 24, title: true); Spacer(); saved; settings } }.atlasPanel(w).placed(.top)
            compass.padding(.top, 100).placed(.topTrailing)
            VStack(spacing: 3) { HStack { search; text(model.city, 17); Spacer(); locate }; ornament }.atlasPanel(w).placed(.bottom) }
    }
    private var ornament: some View {
        Canvas { context, size in
            for i in stride(from: 0, through: Int(size.width / 8), by: 3) {
                let x = CGFloat(i) * 8
                var path = Path(); path.move(to: CGPoint(x: x, y: 0)); path.addLines([CGPoint(x: x, y: 12), CGPoint(x: x + 16, y: 12), CGPoint(x: x + 16, y: 4), CGPoint(x: x + 8, y: 4), CGPoint(x: x + 8, y: 8)])
                context.stroke(path, with: .color(Color(hex: "B69A5E")), lineWidth: 1)
            }
        }.frame(height: 16).accessibilityHidden(true)
    }
    private var skyrim: some View {
        ZStack { HStack(spacing: 22) { text("LOCAL", 15); text("│", 22); text("MAP", 24) }.padding(12).atlasPanel(w).placed(.top)
            compass.padding(.top, 90).placed(.topTrailing)
            VStack(alignment: .leading) { text(model.city.uppercased(), 19); Divider().overlay(p.accent); allTools }.padding(8).atlasPanel(w).placed(.bottom) }
    }
    private var elden: some View {
        ZStack { frame; VStack(alignment: .leading) { text("Map", 30, color: Color(hex: "302C20"), title: true); city }.padding(8).placed(.topLeading)
            compass.padding(.top, 100).placed(.topTrailing)
            VStack { find(); HStack { locate; action("Worlds", actions.worlds); action("Saved", actions.saved); Spacer(); settings } }.padding(8).atlasPanel(w).placed(.bottom) }
    }
    private var animus: some View {
        ZStack { VStack { tabs; Divider().overlay(p.accent); city }.atlasPanel(w).placed(.top)
            compass.padding(.top, 165).placed(.topTrailing); HStack { find(); locate }.padding(8).atlasPanel(w).placed(.bottom) }
    }
    private var ghost: some View {
        ZStack { VStack(alignment: .leading) { tabs; HStack { VStack(alignment: .leading) { text("MAP", 28, color: Color(hex: "252921")); text(model.city, 18, color: Color(hex: "252921")) }; Spacer(); search } }.placed(.top)
            HStack(alignment: .bottom) { compass; Spacer(); VStack(alignment: .trailing) { action("GUIDING ROUTE", { actions.search("") }); action("RECENTER", model.locate); fix } }.placed(.bottom) }
    }
    private var embrace: some View {
        ZStack { HStack { worlds; text("MAP", 23); Spacer(); saved; settings }.atlasPanel(w).placed(.top)
            VStack(alignment: .leading) { city; HStack(alignment: .bottom) { compass; search; locate } }.placed(.bottomLeading) }
    }
    private var hogwarts: some View {
        ZStack { frame; VStack(spacing: 0) { HStack { worlds; text("WORLD MAP", 18, title: true); Spacer(); settings }.atlasPanel(w); text(model.city, 16, title: true).padding(10).frame(maxWidth: .infinity).background(Color(hex: "51353B")) }.placed(.top)
            compass.padding(.top, 160).placed(.topTrailing)
            VStack { find(); HStack { action("Saved", actions.saved); Spacer(); action("Locate", model.locate); tilt } }.placed(.bottom) }
    }
    private var bohemia: some View {
        ZStack { frame; HStack { text("Map", 30, color: Color(hex: "302C20"), title: true); Spacer(); worlds; settings }.padding(8).placed(.top)
            VStack(alignment: .leading) { compass; city; HStack { search; action("Saved", actions.saved); action("Locate", model.locate) } }.padding(8).placed(.bottom) }
    }
    private var farCry: some View {
        ZStack { VStack(alignment: .leading) { tabs; text(model.city, 24).padding(10) }.atlasPanel(w).placed(.top)
            VStack { nearby("Fuel", "fuelpump"); nearby("Food", "fork.knife"); tilt }.placed(.trailing); HStack { find(); locate }.placed(.bottom) }
    }
    private var bridges: some View {
        ZStack { frame; VStack(alignment: .leading) { text("Map / INFORMATION", 24); text(model.city.uppercased(), 15); fix }.placed(.topLeading)
            VStack { search; worlds; saved; settings }.placed(.leading); HStack { action("SET ROUTE", { actions.search("") }); locate; tilt }.placed(.bottomTrailing) }
    }
    private var spider: some View {
        ZStack { frame; VStack { HStack { text("MAP", 25, color: .white).padding(.leading, 12); Spacer(); worlds; settings }.background(Color(hex: "E24350")); city }.atlasPanel(w).placed(.top)
            VStack { search; saved }.placed(.leading); HStack { text("CUSTOM WAYPOINT", 17); Spacer(); search; locate }.padding(8).atlasPanel(w).placed(.bottom) }
    }
    private var starfield: some View {
        ZStack { frame; VStack(alignment: .leading) { text("SURFACE MAP", 22); Divider().frame(width: 200).overlay(p.accent); text(model.city, 18); fix; HStack { worlds; settings } }.placed(.topLeading)
            VStack(alignment: .leading) { compass; HStack { search; Spacer(); action("Saved", actions.saved); action("Locate", model.locate) } }.placed(.bottom) }
    }
    private var saints: some View {
        ZStack { VStack(alignment: .leading) { HStack { text("CITY MAP", 28, color: Color(hex: "D3C5F5")); Spacer(); worlds; settings }; Rectangle().fill(p.accent).frame(height: 3); city }.padding(8).atlasPanel(w).placed(.top)
            VStack { action("LOCATIONS", { actions.search("") }); action("SAVED", actions.saved) }.placed(.leading); HStack { find(); locate }.padding(8).atlasPanel(w).placed(.bottom) }
    }
    private var medici: some View {
        ZStack { frame; VStack(alignment: .leading) { tabs; text(model.city.uppercased(), 26).padding(.top, 10) }.placed(.top)
            VStack(alignment: .trailing) { action("PLACE WAYPOINT", { actions.search("") }); HStack { fix; locate } }.placed(.bottomTrailing) }
    }
    private var mafia: some View {
        ZStack { VStack(spacing: 2) { HStack { text("MAP", 26, title: true); Spacer(); worlds; settings }; Divider().overlay(p.accent); city }.padding(.horizontal, 8).atlasPanel(w).placed(.top)
            HStack { search; Spacer(); action("Saved", actions.saved); action("Center map", model.locate) }.padding(8).atlasPanel(w).placed(.bottom) }
    }
    private var compact: some View {
        ZStack { VStack(alignment: .leading) { tabs; city }.frame(maxWidth: 310).placed(.topLeading)
            HStack { search; locate }.placed(.bottomTrailing); fix.placed(.bottomLeading) }
    }
}

private enum AnyAtlasShape: Shape {
    case circle, panel(World)
    func path(in rect: CGRect) -> Path {
        switch self {
        case .circle: return Circle().path(in: rect)
        case .panel(let w): return AtlasShape(cut: ["night_city","heat","spider"].contains(w.id) ? 10 : 0, round: ["ctos","horizon","old_west","rivia"].contains(w.id) ? 3 : 0).path(in: rect)
        }
    }
}

struct AtlasCompass: View {
    let bearing: Double?
    let world: World
    var ornate = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(world.theme.panel)
                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = size.width / 2 - 7
                    context.stroke(Path(ellipseIn: CGRect(x: 7, y: 7, width: radius * 2, height: radius * 2)), with: .color(world.theme.foreground.opacity(0.65)), lineWidth: 1)
                    var index = Path(); index.move(to: CGPoint(x: c.x, y: 7)); index.addLine(to: CGPoint(x: c.x, y: 14)); context.stroke(index, with: .color(world.theme.foreground), lineWidth: 2)
                    if let bearing {
                        for i in 0..<24 {
                            let a = (Double(i) * 15 - bearing - 90) * .pi / 180
                            let outer = CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
                            let innerR = radius - (i % 6 == 0 ? 10 : 5)
                            var p = Path(); p.move(to: outer); p.addLine(to: CGPoint(x: c.x + cos(a) * innerR, y: c.y + sin(a) * innerR))
                            context.stroke(p, with: .color(world.theme.foreground.opacity(i % 6 == 0 ? 0.85 : 0.35)), lineWidth: 1)
                        }
                        var rose = context; rose.translateBy(x: c.x, y: c.y); rose.rotate(by: .degrees(-bearing)); rose.translateBy(x: -c.x, y: -c.y)
                        var north = Path(); north.move(to: CGPoint(x: c.x, y: 10)); north.addLine(to: CGPoint(x: c.x - 4, y: 22)); north.addLine(to: CGPoint(x: c.x + 4, y: 22)); north.closeSubpath()
                        rose.fill(north, with: .color(["old_west","ghost"].contains(world.id) ? Color(hex: "E0725E") : world.theme.accent))
                    }
                }
                VStack(spacing: 2) {
                    Text(bearing.map { ["N","NE","E","SE","S","SW","W","NW"][Int(($0 + 22.5).truncatingRemainder(dividingBy: 360) / 45)] } ?? "—").font(world.font(ornate ? 23 : 16))
                    if let bearing { Text("\(Int(bearing.rounded()) % 360)°").font(world.font(11)) }
                }.foregroundStyle(world.theme.foreground)
            }.frame(width: ornate ? 96 : 72, height: ornate ? 96 : 72)
        }.buttonStyle(.plain).accessibilityLabel(bearing.map { "Heading \(Int($0)) degrees. Recenter" } ?? "Heading unavailable. Recenter")
    }
}

private extension View {
    func placed(_ alignment: Alignment) -> some View { frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment) }
}
