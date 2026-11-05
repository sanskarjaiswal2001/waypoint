import SwiftUI

struct ReleaseNotesView: View {
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Waypoint for iOS \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0")").font(.title2.bold())
                Group {
                    Text("Search").font(.headline)
                    Text("Results now use Android's name and category matching, include saved and recent places, and check Apple geocoding when Photon finds no strong match. Repeated searches use a small cache kept in memory.")
                    Text("Navigation").font(.headline)
                    Text("After you pan during navigation, the map resumes following eight seconds after the gesture ends. Locate resumes it immediately. GPS course now needs reliable speed and direction readings; the compass takes over when you slow down.")
                    Text("Preferences and guidance").font(.headline)
                    Text("Your travel mode is kept between launches. Arrival and route-deviation thresholds now match Android's active guidance configuration. If a new route cannot load, guidance keeps the current route and shows a message.")
                    Text("Still being tested").font(.headline)
                    Text("Android parity is still in progress. Speech, wrong-turn recovery, arrival and locked-screen use need further device checks. CarPlay and a share extension are not included.")
                }
                Link("iOS releases", destination: URL(string: "https://github.com/sanskarjaiswal2001/waypoint/releases")!)
                Button("Explore map") { model.markReleaseNotesSeen(); dismiss() }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .navigationTitle("What's new")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.markReleaseNotesSeen(); dismiss() } } }
        .onDisappear { model.markReleaseNotesSeen() }
    }
}
