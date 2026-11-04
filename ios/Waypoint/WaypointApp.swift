import SwiftUI

@main
struct WaypointApp: App {
    @State private var model = NavigationModel()
    @Environment(\.scenePhase) private var scenePhase

    init() { SharedArt.install(); BundledGlyphProtocol.install() }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .tint(model.world.accent)
                .onChange(of: scenePhase) { _, phase in model.sceneChanged(phase) }
        }
    }
}
