import SwiftUI
import WaypointKit

struct SearchView: View {
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results = [Place]()
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if loading { HStack { ProgressView(); Text("Searching…") } }
                if let error { Text(error).foregroundStyle(.secondary) }
                ForEach(results) { place in
                    Button {
                        model.select(place)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(place.name).foregroundStyle(.primary)
                            Text(place.address).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                }
                if !loading && error == nil && results.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "Where to?" : "No places found",
                                           systemImage: "magnifyingglass",
                                           description: Text(query.isEmpty ? "Search for a place or address. You can also hold the map to drop a pin." : "Try a different name or a nearby town."))
                }
                Section { Text("Search is provided by Photon using OpenStreetMap data. Your query and approximate search area are sent to Photon.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Search places")
            .searchable(text: $query, prompt: "Place or address")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: query) {
                results = []
                error = nil
                loading = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                guard loading else { return }
                do {
                    try await Task.sleep(for: .milliseconds(450))
                    let found = try await MapService().search(query, near: model.coordinate)
                    try Task.checkCancellation()
                    results = found
                    loading = false
                } catch {
                    guard !Task.isCancelled else { return }
                    self.error = error.localizedDescription
                    loading = false
                }
            }
        }
    }
}

struct WorldsView: View {
    @Bindable var model: NavigationModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(World.all) { world in
                        Button {
                            model.world = world
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14).fill(Color(hex: world.groundHex))
                                    Image(systemName: "map.fill").font(.system(size: 46)).foregroundStyle(world.accent.opacity(0.65))
                                    if model.world.id == world.id {
                                        Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(10)
                                    }
                                }.frame(height: 100)
                                Text(world.title).font(.system(.headline, design: .rounded)).foregroundStyle(world.accent)
                                Text(world.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                Spacer(minLength: 0)
                            }.padding(12).frame(maxWidth: .infinity, minHeight: 205, alignment: .topLeading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityLabel("\(world.title)\(model.world.id == world.id ? ", selected" : "")")
                    }
                }.padding(16)
            }
            .navigationTitle("Choose your world")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct PlacesView: View {
    @Bindable var model: NavigationModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if model.saved.isEmpty && model.recent.isEmpty {
                    ContentUnavailableView("Your places", systemImage: "bookmark", description: Text("Save a destination with the bookmark button. Recent destinations appear after you start navigation."))
                }
                Section("Saved") {
                    ForEach(model.saved) { place in row(place) }
                        .onDelete { offsets in model.saved.remove(atOffsets: offsets) }
                }
                Section("Recent") {
                    ForEach(model.recent) { place in row(place) }
                        .onDelete { offsets in model.recent.remove(atOffsets: offsets) }
                }
            }.navigationTitle("Your places")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func row(_ place: Place) -> some View {
        Button {
            model.select(place)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).foregroundStyle(.primary)
                Text(place.address).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Waypoint for iOS") {
                    Text("Real streets. Another world.").font(.headline)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.1")
                    Text("An experimental native iOS port. Internet access is required for maps, search and routes. No live traffic, offline routing or lane guidance.").font(.footnote)
                }
                Section("Location and privacy") {
                    Text("Location stays on your device except when needed by map and routing providers. Search queries and an optional nearby position go to Photon; route endpoints go to OSRM or Valhalla. Tiles and terrain are fetched from OpenFreeMap and Mapzen. There is no account or analytics service.")
                    Text("Saved and recent destinations stay on this device. Swipe a place in Your places to delete it. Location continues in the background only during active navigation.")
                    Link("Open location settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }.font(.footnote)
                Section("Sideloading") {
                    Text("Install the unsigned IPA through SideStore or AltStore. Your signing app handles signing, device registration and refresh. Keep the same app identity when updating to preserve saved places.").font(.footnote)
                    Link("iOS build and installation guide", destination: URL(string: "https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.1.1/ios/README.md")!)
                }
                Section("Open source") {
                    Link("Waypoint source", destination: URL(string: "https://github.com/the-geeky-couldron/waypoint")!)
                    Link("Ferrostar navigation", destination: URL(string: "https://github.com/stadiamaps/ferrostar")!)
                    Link("MapLibre Native", destination: URL(string: "https://github.com/maplibre/maplibre-native")!)
                    NavigationLink("Licences and map attribution") { NoticesView() }
                    Text("Waypoint is independent and is not affiliated with the games or their publishers.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct NoticesView: View {
    var body: some View {
        ScrollView {
            Text(notices).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
        }.navigationTitle("Licences")
    }

    private var notices: String {
        guard let url = Bundle.main.url(forResource: "notices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "See the source repository for licence notices." }
        return text
    }
}

struct WelcomeView: View {
    @Bindable var model: NavigationModel
    @State private var showWorlds = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 36)
                    Image("WaypointMark").resizable().scaledToFit().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 22))
                    Text("WAYPOINT").font(.system(.caption, design: .monospaced).weight(.bold)).tracking(5).foregroundStyle(model.world.accent)
                    Text("Real streets.\nAnother world.").font(.system(size: 46, weight: .bold, design: .rounded)).minimumScaleFactor(0.7)
                    Text("Explore your world through 27 game-inspired maps. Search for a destination, choose how you travel, and follow spoken directions.")
                        .font(.title3).foregroundStyle(.secondary)
                    Spacer(minLength: 30)
                    Button { showWorlds = true } label: {
                        HStack { Text(model.world.title); Spacer(); Text("Choose world"); Image(systemName: "chevron.right") }
                            .font(.subheadline).padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    Button("Open map") { model.finishWelcome() }
                        .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                    Text("Online services are required. Location is requested when you tap Locate. This iOS preview needs testing on real devices.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(28).frame(minHeight: geometry.size.height, alignment: .leading)
            }.background(LinearGradient(colors: [Color(hex: model.world.groundHex).opacity(0.5), .black], startPoint: .topTrailing, endPoint: .bottomLeading))
        }.sheet(isPresented: $showWorlds) { WorldsView(model: model) }
    }
}
