import SwiftUI
import WaypointKit

private enum Panel: String, Identifiable {
    case search, worlds, saved, settings
    var id: String { rawValue }
}

struct ContentView: View {
    @Bindable var model: NavigationModel
    @State private var panel: Panel?

    var body: some View {
        ZStack {
            WorldMap(model: model).ignoresSafeArea()
            VStack(spacing: 12) {
                header
                if model.navigating { guidance }
                if let problem = model.locationProblem ?? model.mapError ?? model.message {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(problem).font(.footnote)
                        Spacer(minLength: 0)
                        Button { model.message = nil; model.mapError = nil } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Dismiss message")
                    }.padding(14).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    if !model.navigating {
                        action("Saved", icon: "bookmark.fill") { panel = .saved }
                    }
                    Spacer()
                    VStack(spacing: 10) {
                        action(model.tilted ? "2D" : "3D", icon: "view.3d") { model.tilted.toggle() }
                        action("Locate", icon: "location.fill") { model.locate() }
                    }
                }
                if let destination = model.destination { destinationCard(destination) }
                else if !model.navigating {
                    Button { panel = .search } label: {
                        Label("Search places", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity).padding(18)
                    }.buttonStyle(.plain).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
                attribution
            }.padding(.horizontal, 16).padding(.top, 8)
        }
        .sheet(item: $panel) { panel in
            switch panel {
            case .search: SearchView(model: model)
            case .worlds: WorldsView(model: model)
            case .saved: PlacesView(model: model)
            case .settings: SettingsView()
            }
        }
        .fullScreenCover(isPresented: $model.showWelcome) { WelcomeView(model: model) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { panel = .worlds } label: {
                HStack {
                    Image(systemName: "globe.europe.africa.fill")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WAYPOINT").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(3)
                        Text(model.world.title).font(.system(.headline, design: .rounded)).foregroundStyle(model.world.accent)
                    }
                    Image(systemName: "chevron.down").font(.caption)
                }.padding(14)
            }.buttonStyle(.plain).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 0)
            if !model.navigating {
                action("Settings", icon: "gearshape.fill") { panel = .settings }
            }
        }
    }

    private var guidance: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: maneuverSymbol).font(.largeTitle)
                .foregroundStyle(model.world.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                if let distance = model.navigation?.currentProgress?.distanceToNextManeuver {
                    Text(distanceText(distance)).font(.title2.bold()).monospacedDigit()
                }
                Text(model.instruction).font(.headline).fixedSize(horizontal: false, vertical: true)
                if let road = model.navigation?.currentRoadName { Text(road).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            Button { model.toggleMute() } label: {
                Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 44, height: 44)
            }.accessibilityLabel(model.muted ? "Unmute directions" : "Mute directions")
        }.padding(16).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func destinationCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(place.name).font(.headline)
                    Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                if !model.navigating {
                    Button { model.toggleSaved(place) } label: {
                        Image(systemName: model.saved.contains(where: { $0.id == place.id }) ? "bookmark.fill" : "bookmark")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel("Toggle saved place")
                    Button { model.clearDestination() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Clear destination")
                }
            }
            if !model.navigating {
                Picker("Travel mode", selection: Binding(get: { model.mode }, set: { model.changeMode($0) })) {
                    ForEach(TravelMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
                }.pickerStyle(.segmented)
            }
            if model.route != nil {
                HStack(spacing: 22) {
                    Label("\(max(1, Int(ceil(model.duration / 60)))) min", systemImage: "clock")
                    Text(distanceText(model.distance))
                    Spacer(minLength: 0)
                    Text(Date().addingTimeInterval(model.duration), style: .time)
                }.font(.subheadline).monospacedDigit()
            }
            if model.navigating {
                Button("End navigation", role: .destructive) { model.stop() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            } else if model.routing {
                HStack { ProgressView(); Text("Finding a \(model.mode.title.lowercased()) route…") }.frame(maxWidth: .infinity).padding(8)
            } else {
                Button(model.route == nil ? "Preview route" : "Start navigation") {
                    if model.route == nil { model.preview() } else { model.start() }
                }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            }
        }.padding(18).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var maneuverSymbol: String {
        let instruction = model.instruction.lowercased()
        if instruction.contains("arrived") { return "flag.checkered" }
        if instruction.contains("roundabout") { return "arrow.triangle.2.circlepath" }
        if instruction.contains("uturn") || instruction.contains("u-turn") { return "arrow.uturn.down" }
        if instruction.contains("left") { return "arrow.turn.up.left" }
        if instruction.contains("right") { return "arrow.turn.up.right" }
        return "arrow.up"
    }

    private var attribution: some View {
        HStack(spacing: 4) {
            Link("© OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
            Text("·")
            Link("OpenFreeMap", destination: URL(string: "https://openfreemap.org")!)
            Text("·")
            Link("MapLibre", destination: URL(string: "https://maplibre.org")!)
        }.font(.system(size: 10)).padding(6).background(.thickMaterial, in: Capsule())
            .padding(.bottom, 4)
    }

    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .semibold))
            }.frame(minWidth: 58, minHeight: 58)
        }.buttonStyle(.plain).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

func distanceText(_ metres: Double) -> String {
    metres < 1000 ? "\(Int(metres.rounded())) m" : String(format: "%.1f km", metres / 1000)
}
