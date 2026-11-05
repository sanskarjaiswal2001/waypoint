import SwiftUI

struct ReleaseNotesView: View {
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Waypoint for iOS \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0")").font(.title2.bold())
                Group {
                    Text("Worlds and Quests").font(.headline)
                    Text("The catalogue now follows Android 2.0.1 with 38 worlds, shared typography and themed vehicle markers. Every idle map opens Quests, with local tasks, explicit completion, Undo and a focus timer. Photos and quest notifications are not included in this preview.")
                    Text("Search").font(.headline)
                    Text("Results now use Android's name and category matching, include saved and recent places, and check Apple geocoding when Photon finds no strong match. Repeated searches use a small cache kept in memory.")
                    Text("Navigation").font(.headline)
                    Text("After you pan during navigation, the map resumes following eight seconds after the gesture ends. Locate resumes it immediately. GPS course now needs reliable speed and direction readings; the compass takes over when you slow down.")
                    Text("Preferences and guidance").font(.headline)
                    Text("Bicycle has its own routing profile, and your travel mode is kept between launches. Saved places can be renamed. Arrival and route-deviation thresholds match Android's active guidance configuration. If a new route cannot load, guidance keeps the current route and shows a message.")
                    Text("Still being tested").font(.headline)
                    Text("Android parity is still in progress. Speech, wrong-turn recovery, arrival and locked-screen use need further device checks. CarPlay and a share extension are not included.")
                }
                Link("iOS releases", destination: URL(string: "https://github.com/the-geeky-couldron/waypoint/releases")!)
                Button("Explore map") { model.markReleaseNotesSeen(); dismiss() }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .navigationTitle("What's new")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.markReleaseNotesSeen(); dismiss() } } }
        .onDisappear { model.markReleaseNotesSeen() }
    }
}
