import SwiftUI
import WaypointKit

private enum Panel: String, Identifiable {
    case search, worlds, saved, settings, steps
    var id: String { rawValue }
}

struct ContentView: View {
    @Bindable var model: NavigationModel
    @State private var panel: Panel?
    @State private var searchQuery = ""
    @State private var replayIntroPending = false
    @State private var showImportConfirmation = false

    var body: some View {
        ZStack {
            WorldMap(model: model).ignoresSafeArea()
            if model.destination == nil && !model.navigating {
                AtlasChrome(model: model, actions: AtlasActions(search: { query in searchQuery = query; panel = .search }, worlds: { panel = .worlds }, saved: { panel = .saved }, settings: { panel = .settings }))
                notices.padding(.horizontal, 16).padding(.top, 160).frame(maxHeight: .infinity, alignment: .top)
            } else {
                GeometryReader { size in
                    if size.size.width > size.size.height && size.size.height < 500 {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 8) { routeHeader; if model.navigating { guidance }; notices; Spacer(minLength: 0); routeControls }
                            if let destination = model.destination { ScrollView { destinationCard(destination) }.frame(width: min(340, size.size.width * 0.43)) }
                        }.padding(12)
                    } else {
                        VStack(spacing: 10) { routeHeader; if model.navigating { guidance }; notices; Spacer(minLength: 0); routeControls; if let destination = model.destination { destinationCard(destination) } }.padding(16)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { attribution }
        .tint(model.world.theme.accent)
        .sheet(item: $panel, onDismiss: {
            if replayIntroPending { replayIntroPending = false; model.showWelcome = true }
            else if model.pendingImport != nil && !model.showWelcome { showImportConfirmation = true }
        }) { panel in
            Group {
                switch panel {
                case .search: SearchView(model: model, initialQuery: searchQuery)
                case .worlds: WorldsView(model: model)
                case .saved: PlacesView(model: model)
                case .settings: SettingsView(model: model, replayIntroduction: { replayIntroPending = true; self.panel = nil })
                case .steps: RouteStepsView(model: model)
                }
            }.tint(model.world.theme.accent).preferredColorScheme(["ctos","horizon"].contains(model.world.id) ? .light : .dark)
        }
        .fullScreenCover(isPresented: $model.showWelcome, onDismiss: { if model.pendingImport != nil { showImportConfirmation = true } }) { WelcomeView(model: model) }
        .onOpenURL { model.offerImport($0.absoluteString) }
        .onChange(of: model.pendingImport) { _, proposal in
            guard proposal != nil else { return }
            if panel != nil { panel = nil }
            else if !model.showWelcome { showImportConfirmation = true }
        }
        .alert("Open shared destination?", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { model.pendingImport = nil }
            Button("Open destination") {
                guard !model.navigating, let proposal = model.pendingImport else { return }
                model.pendingImport = nil
                switch proposal {
                case .point(let coordinate, let label): model.select(Place(id: "shared:\(UUID().uuidString)", name: label, address: "Shared destination", coordinate: coordinate)); model.preview()
                case .search(let query): searchQuery = query; panel = .search
                }
            }
        } message: { Text(importDescription) }
        .task { await model.checkForUpdate(quiet: true) }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                model.checkGPS()
            }
        }
    }
    private var importDescription: String {
        var value = model.pendingImport?.title ?? ""
        if case .point(let coordinate, _) = model.pendingImport {
            value += "\n" + String(format: "%.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), coordinate.latitude, coordinate.longitude)
        }
        return value + "\nWaypoint will look up this place or preview a route after you continue."
    }
    private var routeControls: some View {
        HStack(alignment: .bottom) {
            if model.navigating { VStack(spacing: 0) { Text(model.speedText).font(model.world.font(30)); Text(model.imperial ? "mph" : "km/h").font(.caption) }.padding(12).atlasPanel(model.world) }
            Spacer()
            HStack { control("Map tilt", "view.3d") { model.tilted.toggle() }; control("Locate", "location.viewfinder", model.locate) }
        }
    }
    @ViewBuilder private var notices: some View {
        VStack(spacing: 6) {
            if let update = model.availableUpdate, !model.navigating, model.destination == nil, !model.showWelcome {
                HStack { Text("Waypoint iOS \(update.version) is available.").font(.footnote); Spacer(); Link("View update", destination: update.url); Button { model.availableUpdate = nil } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }.accessibilityLabel("Later") }.padding(12).atlasPanel(model.world)
            }
            if let problem = model.mapError {
                HStack(alignment: .top) { Image(systemName: "map.fill"); Text(problem).font(.footnote); Spacer(minLength: 0); Button("Retry map") { model.retryMap() }.font(.footnote.bold()) }.padding(12).atlasPanel(model.world)
            }
            if let problem = model.locationProblem ?? (model.gpsStale ? "GPS position is stale. Waiting for a fresh location." : nil) ?? model.message {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill"); Text(problem).font(.footnote); Spacer(minLength: 0)
                    if model.locationProblem == nil && !model.gpsStale { Button { model.message = nil } label: { Image(systemName: "xmark").frame(minWidth: 32, minHeight: 32) }.accessibilityLabel("Dismiss message") }
                }.padding(12).atlasPanel(model.world)
            }
        }
    }
    private var routeHeader: some View {
        HStack {
            Button { panel = .worlds } label: {
                HStack {
                    if let image = SharedArt.image("world_emblem_\(model.world.id)") { Image(uiImage: image).resizable().scaledToFit().frame(width: 32, height: 32) }
                    VStack(alignment: .leading, spacing: 2) { Text(model.world.title).font(model.world.font(23, title: true)); Text(model.world.inspiration).font(.system(size: 10)).foregroundStyle(model.world.theme.muted) }
                    Image(systemName: "chevron.down")
                }.padding(10)
            }.buttonStyle(.plain).accessibilityLabel("Worlds")
            Spacer(minLength: 0)
            control("Settings", "slider.horizontal.3") { panel = .settings }
        }.atlasPanel(model.world)
    }
    private var guidance: some View {
        Button { panel = .steps } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: maneuverSymbol(model.instruction)).font(.largeTitle).foregroundStyle(model.world.theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(!model.hasFreshFix ? "Finding GPS" : model.navigation?.isCalculatingNewRoute == true ? "Rerouting…" : model.distanceText(model.navigation?.currentProgress?.distanceToNextManeuver ?? 0)).font(model.world.font(32)).foregroundStyle(model.world.theme.accent)
                    Text(model.hasFreshFix ? model.instruction : "Waiting for a fresh, accurate location").font(.system(size: 16)).multilineTextAlignment(.leading).lineLimit(3)
                    if let road = model.navigation?.currentRoadName { Text(road).font(.caption).foregroundStyle(model.world.theme.muted) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
            }.padding(16).atlasPanel(model.world)
        }.buttonStyle(.plain).accessibilityLabel("\(model.instruction). Show route steps")
    }
    private func destinationCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.navigating {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) { Text(place.name).font(model.world.font(24)); Text(place.address).font(.caption).foregroundStyle(model.world.theme.muted).lineLimit(2) }
                    Spacer(minLength: 0)
                    Button { model.toggleSaved(place) } label: { Image(systemName: model.saved.contains(where: { $0.id == place.id }) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44) }.accessibilityLabel("Save destination")
                    Button { model.clearDestination() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Clear destination")
                }
                Picker("Travel mode", selection: Binding(get: { model.mode }, set: model.changeMode)) { ForEach(TravelMode.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            }
            if model.route != nil {
                HStack(spacing: 12) {
                    if model.navigating { Button { model.stop() } label: { Label("End trip", systemImage: "xmark").labelStyle(.iconOnly).frame(width: 44, height: 50) }.accessibilityLabel("End navigation") }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) { Text("\(max(1, Int(ceil(model.duration / 60)))) min").font(model.world.font(29)).foregroundStyle(model.world.theme.accent); Text(model.distanceText(model.distance)).font(.subheadline) }
                        HStack(spacing: 4) { Text(Date().addingTimeInterval(model.duration), style: .time); Text("arrival"); if model.navigating { Text("· \(model.speedText) \(model.imperial ? "mph" : "km/h")") } }.font(.caption).foregroundStyle(model.world.theme.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button { panel = .steps } label: { VStack(spacing: 4) { Image(systemName: "list.bullet"); Text("Steps").font(.caption) }.frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Route steps")
                    if model.navigating { Button { model.toggleMute() } label: { Image(systemName: model.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill").frame(width: 44, height: 44) }.accessibilityLabel(model.voiceEnabled ? "Mute guidance" : "Unmute guidance") }
                }
            }
            if !model.navigating {
                if model.routing { HStack { ProgressView(); Text("Finding a \(model.mode.title.lowercased()) route…") }.frame(maxWidth: .infinity).padding(8) }
                else {
                    Button(model.route == nil ? "Preview route" : "Start navigation") { if model.route == nil { model.preview() } else { model.start() } }
                        .font(model.world.font(21)).frame(maxWidth: .infinity, minHeight: 50).foregroundStyle(Color(hex: model.world.theme.panelHex)).background(model.world.theme.accent).clipShape(AtlasShape(cut: model.world.id == "night_city" ? 10 : 0))
                }
            }
        }.padding(14).atlasPanel(model.world)
    }
    private var attribution: some View {
        HStack(spacing: 4) {
            Link("© OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org/copyright")!); Text("·")
            Link("OpenFreeMap", destination: URL(string: "https://openfreemap.org")!); Text("·")
            Link("MapLibre", destination: URL(string: "https://maplibre.org")!)
        }.font(.system(size: 10)).padding(6).atlasPanel(model.world).frame(maxWidth: .infinity).padding(.bottom, 2)
    }
    private func control(_ title: String, _ icon: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) { VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 20)); Text(title).font(SharedArt.font("roboto_condensed", 12)) }.frame(minWidth: 56, minHeight: 56) }.buttonStyle(.plain).atlasPanel(model.world).accessibilityLabel(title)
    }
}

func maneuverSymbol(_ instruction: String) -> String {
    let text = instruction.lowercased()
    if text.contains("arriv") { return "flag.checkered" }
    if text.contains("roundabout") || text.contains("rotary") { return "arrow.triangle.2.circlepath" }
    if text.contains("uturn") || text.contains("u-turn") { return "arrow.uturn.down" }
    if text.contains("left") { return "arrow.turn.up.left" }
    if text.contains("right") { return "arrow.turn.up.right" }
    return "arrow.up"
}
