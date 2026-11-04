import AVFoundation
import SwiftUI
import WaypointKit

struct SearchView: View {
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results = [Place]()
    @State private var loading = false
    @State private var error: String?
    init(model: NavigationModel, initialQuery: String = "") { self.model = model; _query = State(initialValue: initialQuery) }
    var body: some View {
        NavigationStack {
            List {
                Picker("Travel mode", selection: Binding(get: { model.mode }, set: model.changeMode)) { ForEach(TravelMode.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                if query.isEmpty {
                    Section("Nearby") { HStack { ForEach(["Coffee","Food","Fuel","Parking"], id: \.self) { value in Button(value) { query = value }.buttonStyle(.bordered) } } }
                }
                if NavigationImport.parse(query) != nil {
                    Button("Open shared destination") { model.offerImport(query); dismiss() }
                }
                if loading { HStack { ProgressView(); Text("Searching…") } }
                if let error { Text(error).foregroundStyle(.secondary) }
                ForEach(results) { place in
                    Button { model.select(place); dismiss() } label: {
                        HStack { Image(systemName: "mappin.and.ellipse").foregroundStyle(model.world.theme.accent)
                            VStack(alignment: .leading, spacing: 5) { Text(place.name).foregroundStyle(.primary); Text(place.address).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); if let coordinate = model.coordinate { Text(model.distanceText(coordinate.distance(to: place.coordinate))).font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 6)
                    }
                }
                if !loading && error == nil && results.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "Where to?" : "No places found", systemImage: "magnifyingglass", description: Text(query.isEmpty ? "Search for a place or address, or hold the map to drop a pin." : "Try a different name or a nearby town."))
                }
                Section { Text("Search is provided by Photon using OpenStreetMap data. Your query and approximate search area are sent to Photon.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("Search places").searchable(text: $query, prompt: "Place or address")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task(id: query) {
                    results = []; error = nil; loading = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    guard loading else { return }
                    if NavigationImport.parse(query) != nil { loading = false; return }
                    do {
                        try await Task.sleep(for: .milliseconds(450))
                        let found = try await MapService().search(query, near: model.coordinate)
                        try Task.checkCancellation(); results = found; loading = false
                    } catch { guard !Task.isCancelled else { return }; self.error = error.localizedDescription; loading = false }
                }
        }
    }
}

struct WorldsView: View {
    @Bindable var model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var favoritesOnly = false
    private var worlds: [World] { World.all.filter { (!favoritesOnly || model.favoriteWorlds.contains($0.id)) && (query.isEmpty || ($0.title + " " + $0.inspiration).localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                HStack { Text("YOUR MAP. YOUR WORLD.").font(SharedArt.font("barlow_condensed_bold", 24)); Spacer(); Toggle("Favourites", isOn: $favoritesOnly).labelsHidden(); Text("Favourites").font(.caption) }.padding(.horizontal)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                    ForEach(worlds) { world in
                        VStack(alignment: .leading, spacing: 0) {
                            Button { model.world = world; dismiss() } label: { WorldCard(world: world, selected: model.world.id == world.id) }.buttonStyle(.plain).accessibilityLabel("\(world.title)\(model.world.id == world.id ? ", selected" : "")")
                            Button { model.toggleFavorite(world) } label: { Label(model.favoriteWorlds.contains(world.id) ? "Favourite" : "Add favourite", systemImage: model.favoriteWorlds.contains(world.id) ? "star.fill" : "star").font(.caption).frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.plain)
                        }.atlasPanel(world)
                    }
                }.padding(16)
                if worlds.isEmpty { ContentUnavailableView("No worlds", systemImage: "globe", description: Text("Try another game name or turn off the favourites filter.")) }
            }.navigationTitle("Choose your world").searchable(text: $query, prompt: "World or game")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct WorldCard: View {
    let world: World
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let image = SharedArt.image("art_\(world.id)") { Image(uiImage: image).resizable().scaledToFill().frame(height: 130).clipped() }
                else { Rectangle().fill(Color(hex: world.groundHex)).frame(height: 130) }
                if selected { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.white).shadow(radius: 3).padding(8) }
            }
            HStack(spacing: 8) {
                if let image = SharedArt.image("world_emblem_\(world.id)") { Image(uiImage: image).resizable().scaledToFit().frame(width: 28, height: 28) }
                Text(world.title).font(world.font(21, title: true)).lineLimit(2).minimumScaleFactor(0.8)
            }.padding(.horizontal, 10)
            Text(world.inspiration).font(.caption).foregroundStyle(world.theme.muted).lineLimit(2).padding(.horizontal, 10)
            Text(world.subtitle).font(.system(size: 10)).foregroundStyle(world.theme.accent).padding(.horizontal, 10).padding(.bottom, 12)
        }.foregroundStyle(world.theme.foreground).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlacesView: View {
    @Bindable var model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if model.saved.isEmpty && model.recent.isEmpty { ContentUnavailableView("Your places", systemImage: "bookmark", description: Text("Save a destination with the bookmark button. Recent destinations appear after you start navigation.")) }
                Section("Saved") { ForEach(model.saved) { place in row(place) }.onDelete { model.saved.remove(atOffsets: $0) } }
                Section("Recent") { ForEach(model.recent) { place in row(place) }.onDelete { model.recent.remove(atOffsets: $0) } }
            }.navigationTitle("Your places").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func row(_ place: Place) -> some View {
        Button { model.select(place); dismiss() } label: { VStack(alignment: .leading, spacing: 5) { Text(place.name).foregroundStyle(.primary); Text(place.address).font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 4) }
    }
}

struct RouteStepsView: View {
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Label(model.distanceText(model.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath"); Spacer(); Text("\(max(1, Int(ceil(model.duration / 60)))) min") } }
                ForEach(Array(((model.navigating ? model.navigation?.remainingSteps : model.route?.steps) ?? []).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: maneuverSymbol(step.instruction)).font(.title2).foregroundStyle(model.world.theme.accent).frame(width: 30)
                        VStack(alignment: .leading, spacing: 5) { Text(step.instruction); Text(model.distanceText(step.distance)).font(.caption).foregroundStyle(.secondary) }
                        if model.navigation?.currentStep == step { Image(systemName: "location.fill").foregroundStyle(model.world.theme.accent).accessibilityLabel("Current step") }
                    }.padding(.vertical, 8)
                }
            }.navigationTitle("Your route").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct SettingsView: View {
    @Bindable var model: NavigationModel
    let replayIntroduction: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var clearConfirm = false
    var body: some View {
        NavigationStack {
            List {
                Section("Navigation") {
                    Toggle("Spoken directions", isOn: $model.voiceEnabled)
                    Toggle("Miles and feet", isOn: $model.imperial)
                    Toggle("3D perspective", isOn: $model.tilted)
                    Picker("Travel mode", selection: Binding(get: { model.mode }, set: model.changeMode)) { ForEach(TravelMode.allCases, id: \.self) { Text($0.title).tag($0) } }.disabled(model.navigating)
                    Text("Background location and the screen-awake state are used only during active navigation.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Location") {
                    LabeledContent("Status", value: model.fixLabel)
                    if let fix = model.fix { LabeledContent("Accuracy", value: "±\(Int(fix.horizontalAccuracy.rounded())) m"); LabeledContent("Last reading", value: "\(max(0, Int(-fix.timestamp.timeIntervalSinceNow))) seconds ago") }
                    LabeledContent("Heading", value: model.bearing.map { "\(Int($0.rounded()))°" } ?? "Unavailable")
                    LabeledContent("Provider", value: "Core Location")
                    if let problem = model.locationProblem { Text(problem).font(.footnote) }
                    Button("Find my location", action: model.locate)
                    Link("Open location settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                Section("Your places and worlds") {
                    Button("Replay introduction") { replayIntroduction(); dismiss() }
                    Button("Clear saved places and history", role: .destructive) { clearConfirm = true }
                }
                Section("Feedback") { NavigationLink("Send feedback") { FeedbackView(world: model.world) } }
                Section("Waypoint for iOS") {
                    Text("Real streets. Another world.").font(SharedArt.font("barlow_condensed_bold", 24))
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0")
                    Button(model.checkingUpdates ? "Checking…" : "Check for updates") { Task { await model.checkForUpdate() } }.disabled(model.checkingUpdates || model.navigating)
                    if let status = model.updateStatus { Text(status).font(.footnote) }
                    if let update = model.availableUpdate { Link("Review version \(update.version)", destination: update.url) }
                    Link("iOS releases and updates", destination: URL(string: "https://github.com/sanskarjaiswal2001/waypoint/releases")!)
                    Text("Install updates through the same LiveContainer or signing app to preserve your saved places.").font(.footnote).foregroundStyle(.secondary)
                    Link("iOS build and installation guide", destination: URL(string: "https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.2.0/ios/README.md")!)
                }
                Section("Location and privacy") {
                    Text("Search queries and an optional nearby position go to Photon; route endpoints go to OSRM or Valhalla. Tiles and terrain come from OpenFreeMap and Mapzen. Core Location reverse geocoding supplies the current city label. There is no account or analytics service. Saved and recent destinations stay on this device.").font(.footnote)
                }
                Section("Open source") {
                    Link("Waypoint source", destination: URL(string: "https://github.com/the-geeky-couldron/waypoint")!)
                    Link("Ferrostar navigation", destination: URL(string: "https://github.com/stadiamaps/ferrostar")!)
                    Link("MapLibre Native", destination: URL(string: "https://maplibre.org")!)
                    NavigationLink("Licences and map attribution") { NoticesView() }
                    Text("Waypoint is independent and is not affiliated with the games or their publishers.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Clear your places?", isPresented: $clearConfirm, titleVisibility: .visible) { Button("Clear places", role: .destructive) { model.clearPlaces() } } message: { Text("This removes saved destinations and recent navigation history from this device.") }
        }
    }
}

struct FeedbackView: View {
    let world: World
    @Environment(\.openURL) private var openURL
    @State private var kind = "Bug"
    @State private var title = ""
    @State private var details = ""
    private var issueURL: URL? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var url = URLComponents(string: "https://github.com/sanskarjaiswal2001/waypoint/issues/new")!
        url.queryItems = [URLQueryItem(name: "title", value: String(title.prefix(160))), URLQueryItem(name: "body", value: "### My feedback\n\n\(details.prefix(4000))\n\n### App context\n\n- Type: \(kind)\n- World: \(world.title)\n- Waypoint iOS version: \(version)")]
        guard let result = url.url, result.absoluteString.count <= 6500 else { return nil }; return result
    }
    var body: some View {
        Form {
            Picker("Type", selection: $kind) { ForEach(["Bug","Idea","Other"], id: \.self) { Text($0) } }
            TextField("Title", text: $title)
            Section("Details") { TextEditor(text: $details).frame(minHeight: 180) }
            Text("This opens a draft GitHub issue with your feedback, selected world and app version. Review it in your browser before submitting. No location or route is attached.").font(.footnote).foregroundStyle(.secondary)
            Button("Review on GitHub") { if let url = issueURL { openURL(url) } }.disabled(issueURL == nil)
        }.navigationTitle("Send feedback")
    }
}

private struct NoticesView: View {
    var body: some View { ScrollView { Text(notices).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }.navigationTitle("Licences") }
    private var notices: String { guard let url = Bundle.main.url(forResource: "notices", withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) else { return "See the source repository for licence notices." }; return text }
}

struct WelcomeView: View {
    @Bindable var model: NavigationModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var referral = UserDefaults.standard.string(forKey: "referral") ?? ""
    private let referrals = ["YouTube", "Instagram", "Reddit", "Twitter / X", "Friend or family", "GitHub", "Other"]
    var body: some View {
        GeometryReader { size in
            ZStack {
                LinearGradient(colors: [Color(hex: "0A0E17"), Color(hex: "030722")], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                if page < 3 { story(size.size) }
                else if page == 3 { referralPage }
                else if page == 4 { favoritesPage }
                else if page == 5 { worldPage }
                else { locationPage }
                VStack {
                    HStack {
                        if page > 0 { Button { page -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Back") }
                        Spacer()
                        if page < 3 { Button("Skip introduction") { page = 3 }.font(.caption).padding(12) }
                    }
                    Spacer()
                    HStack(spacing: 6) { ForEach(0..<7) { dot in Capsule().fill(dot == page ? .white : .white.opacity(0.25)).frame(width: dot == page ? 22 : 6, height: 6) } }.padding(.bottom, 12)
                    Button(page == 6 ? "Open map" : "Continue") {
                        if page == 6 { model.finishWelcome() }
                        else {
                            if page == 3 { UserDefaults.standard.set(referral, forKey: "referral") }
                            if page == 4, let id = model.favoriteWorlds.first, let world = World.all.first(where: { $0.id == id }) { model.world = world }
                            page += 1
                        }
                    }.font(SharedArt.font("barlow_condensed_bold", 23)).frame(maxWidth: .infinity, minHeight: 54).foregroundStyle(Color(hex: "122543")).background(.white, in: Capsule()).padding(.horizontal, 24)
                        .disabled(page == 4 && model.favoriteWorlds.isEmpty)
                }.padding(.bottom, 16)
            }.foregroundStyle(.white)
        }.preferredColorScheme(.dark).tint(Color(hex: "224D91"))
    }
    private func story(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            if page == 2 { HorsePhoneHero().frame(height: size.height * 0.5).accessibilityHidden(true) }
            else if reduceMotion { Image(systemName: page == 0 ? "globe.europe.africa.fill" : "mappin.and.ellipse").font(.system(size: 150)).frame(height: size.height * 0.48).foregroundStyle(Color(hex: "9DC4FF")) }
            else { LoopingMotion(name: ["onboarding_globe_motion","onboarding_icons_motion"][page]).id(page).frame(height: size.height * 0.5).allowsHitTesting(false) }
            VStack(spacing: 3) {
                Text(["Waypoint\nReal streets\nnew worlds", "Map Icons of your\nfavourite game", "Navigate with\nyour phone"][page]).font(SharedArt.font("barlow_condensed_bold", size.width < 360 ? 37 : 45)).multilineTextAlignment(.center)
                Text(["Find your favourite game. Explore real roads through another world.", "Real streets, familiar icons, typography and maps inspired by the games you love.", "Follow real routes on a game-inspired map with clear turn-by-turn voice guidance."][page]).font(.system(size: 16)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).padding(.top, 12)
            }.padding(.horizontal, 24)
            Spacer(minLength: 100)
        }
    }
    private var referralPage: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("How did you find\nWaypoint?").font(SharedArt.font("barlow_condensed_bold", 39))
            ForEach(referrals, id: \.self) { value in Button { referral = value } label: { HStack { Text(value); Spacer(); Image(systemName: referral == value ? "checkmark.circle.fill" : "circle") }.padding(18).background(.white.opacity(referral == value ? 0.22 : 0.08), in: Capsule()) }.buttonStyle(.plain) }
            Text("Optional. Your choice is stored on this device.").font(.footnote).foregroundStyle(.white.opacity(0.7))
        }.padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 130) }
    }
    private var favoritesPage: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) {
            Text("Your favourite\ngames").font(SharedArt.font("barlow_condensed_bold", 39))
            Text("Choose as many as you like.").foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 10) {
                ForEach(World.all) { world in Button { model.toggleFavorite(world) } label: {
                    HStack { if let image = SharedArt.image("world_emblem_\(world.id)") { Image(uiImage: image).resizable().scaledToFit().frame(width: 28, height: 28) }; Text(world.inspiration).font(.system(size: 13)).lineLimit(2); Spacer(minLength: 0); if model.favoriteWorlds.contains(world.id) { Image(systemName: "checkmark") } }.padding(12).frame(minHeight: 60).background(.white.opacity(model.favoriteWorlds.contains(world.id) ? 0.22 : 0.08), in: Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(model.favoriteWorlds.contains(world.id) ? .isSelected : []) }
            }
        }.padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 130) }
    }
    private var worldPage: some View {
        VStack(spacing: 14) {
            Text("Choose your world").font(SharedArt.font("barlow_condensed_bold", 36)).padding(.top, 60)
            Text("Swipe to preview all 27 worlds.").foregroundStyle(.white.opacity(0.7))
            TabView(selection: Binding(get: { model.world.id }, set: { id in if let world = World.all.first(where: { $0.id == id }) { model.world = world } })) {
                ForEach(World.all.sorted { model.favoriteWorlds.contains($0.id) && !model.favoriteWorlds.contains($1.id) }) { world in WorldCard(world: world, selected: model.world.id == world.id).atlasPanel(world).padding(.horizontal, 24).tag(world.id) }
            }.tabViewStyle(.page(indexDisplayMode: .always)).frame(maxHeight: 400)
            Text(model.world.subtitle).font(model.world.font(20, title: true)).foregroundStyle(model.world.accent)
            Spacer(minLength: 110)
        }
    }
    private var locationPage: some View {
        VStack(spacing: 22) {
            Spacer(); Image(systemName: "location.circle").font(.system(size: 100)).foregroundStyle(Color(hex: "9DC4FF"))
            Text("Find your way").font(SharedArt.font("barlow_condensed_bold", 39))
            Text("Allow precise location to find your position and guide you. You can also browse the map first and tap Locate later.").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
            Button("Enable precise location") { model.locate() }.buttonStyle(.borderedProminent).controlSize(.large)
            if let problem = model.locationProblem { Text(problem).font(.footnote).multilineTextAlignment(.center) }
            Spacer(); Spacer(minLength: 100)
        }.padding(.horizontal, 30)
    }
}

private struct LoopingMotion: UIViewRepresentable {
    let name: String
    @Environment(\.scenePhase) private var scenePhase
    final class VideoView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var queue: AVQueuePlayer?
        var looper: AVPlayerLooper?
        func load(_ url: URL) { let queue = AVQueuePlayer(); queue.isMuted = true; self.queue = queue; looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url)); (layer as? AVPlayerLayer)?.player = queue; (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect; queue.play() }
    }
    func makeUIView(context: Context) -> VideoView { let view = VideoView(); if let url = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "motion") { view.load(url) }; return view }
    func updateUIView(_ uiView: VideoView, context: Context) { if scenePhase == .active { uiView.queue?.play() } else { uiView.queue?.pause() } }
    static func dismantleUIView(_ uiView: VideoView, coordinator: ()) { uiView.queue?.pause(); uiView.looper?.disableLooping() }
}
