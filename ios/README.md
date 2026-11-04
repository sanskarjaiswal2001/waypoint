# Waypoint for iOS

A native SwiftUI port for iPhone and iPad on **iOS 17 or later**. It shares the Android app's 27 MapLibre styles, bundled map fonts, map patterns and online providers. Ferrostar 0.59.0 handles route progress, spoken instructions, arrival and rerouting.

This is an experimental preview. Device installation, background guidance, GPS reliability and real-road behaviour need validation before treating it as a daily navigation app. CarPlay, Android's in-app updater and incoming destination links are not part of this initial port. The iOS screens use native controls; the Android onboarding animations and individual game HUD layouts have not been ported.

## Install through SideStore or AltStore Classic

1. Set up [SideStore](https://docs.sidestore.io/docs/installation/install) or [AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore) using its official instructions. Enable Developer Mode on the device if the installer requests it.
2. Open this fork's [Releases](https://github.com/sanskarjaiswal2001/waypoint/releases) and download **Waypoint-iOS-unsigned.ipa** from an iOS preview release to Files on your device.
3. In SideStore or AltStore Classic, open **My Apps**, tap **+**, and choose the downloaded IPA. The installer signs it with your account and installs it.
4. Open Waypoint, choose a world and tap **Open map**. Tap **Locate**, allow location access with **Precise Location** enabled, then search for a destination or hold the map to drop a pin.
5. Choose Car, Motorcycle or Walk, tap **Preview route**, and review it before starting navigation.

The IPA is deliberately unsigned and cannot be installed by tapping it directly in Files. It contains one arm64 device app, no app extensions and no restricted CarPlay entitlement. SideStore/AltStore handles signing and refresh. Free-account signatures normally need refreshing within seven days; follow the installer's current guidance and account limits. AltStore PAL is a different distribution system and is not the IPA-import route described here.

For updates, import the newer IPA using the same installer, account and app identity. Avoid deleting the existing app if you want to keep its saved places. Checksums are published in **SHA256SUMS-iOS**:

```sh
shasum -a 256 -c SHA256SUMS-iOS
```

## Build

### SwiftPM and xtool

An unsigned IPA can also be built with [xtool](https://github.com/xtool-org/xtool), using the existing Command Line Tools as the host toolchain and the iOS platform files from a user-folder Xcode installation. This path was tested with xtool 1.24.0, Swift 6.4 Command Line Tools and Xcode 27.2 in `~/Applications`, without administrator access.

Install xtool from its official release or Homebrew tap, and ensure your Xcode app contains the iOS SDK. Then run:

```sh
bash scripts/build_ios_xtool.sh
```

If xtool is not on your `PATH`, or Xcode is in another location:

```sh
WAYPOINT_XTOOL="/path/to/xtool.app/Contents/MacOS/xtool" \
WAYPOINT_XCODE_APP="$HOME/Applications/Xcode.app" \
bash scripts/build_ios_xtool.sh
```

The script uses Swift Build through xtool, stages iOS platform links under the ignored `ios/build/` directory, and packages `ios/build/release/Waypoint-iOS-unsigned.ipa`. Signing and Apple-account login are handled later by SideStore or AltStore. Toolchain and platform compatibility can vary with installed versions.

### Xcode build

Install **Xcode 26 or later**, its iOS SDK and command-line tools, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Select the full Xcode installation in `xcode-select`.

```sh
brew install xcodegen
swift test --package-path ios/WaypointKit
bash scripts/build_ios.sh
```

The output is `ios/build/release/Waypoint-iOS-unsigned.ipa`. The packaging script verifies its arm64 architecture and iOS device Mach-O platform, strips embedded signature resources and provisioning profiles, checks ZIP integrity and writes its SHA-256 checksum. Apple credentials are not required to compile this unsigned build.

For development in Xcode:

```sh
python3 scripts/prepare_ios.py
xcodegen generate --spec ios/project.yml
open ios/Waypoint.xcodeproj
```

Generated projects, staged resources, package build caches and IPAs are ignored. Shared resources are staged from the Android tree rather than duplicated in Git. Change `ios/project.yml` rather than the generated project. To install directly from Xcode, configure your own development team and enable signing locally.

## CI and releases

The iOS workflow runs core routing/search tests and compiles a Release device build on a macOS runner. Branch builds upload the IPA as a workflow artifact. Push an `ios-v*` tag to build and publish an iOS prerelease with the IPA and checksum. The separate tag prefix leaves the Android release workflow and stable update channel alone.

Before tagging, update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `ios/project.yml` and review `ios/RELEASE_NOTES.md`. Commit the resolved Swift package file when dependencies change; the build stages it into the generated project before resolving packages.

## Privacy, services and validation

- Map tiles and labels: OpenFreeMap / OpenStreetMap; terrain: Mapzen.
- Place search: Photon. The query and optional nearby position are sent to the service.
- Car routes: OSRM. Motorcycle and walking routes: Valhalla using their distinct costing profiles.
- Guidance: Ferrostar on-device, with iOS text-to-speech and Core Location.
- Saved places, recent destinations and selected world: local app preferences. No account or analytics service.

Location is requested only after **Locate** or an explicit route preview. Background location is enabled only while navigating. Ending a trip releases background location and the screen-awake state. The map can be browsed without granting location. Search needs no GPS fix, while route preview and navigation require a recent position with adequate accuracy. Online providers can be unavailable or rate-limited. There is no offline routing, live traffic or lane guidance.

Core tests cover provider selection, coordinate order, malformed responses, bounded geometry and upcoming-turn prompts. A compiled IPA does not establish real-road safety or installation compatibility. Before expanding the release beyond a preview, validate on a physical device: SideStore/AltStore installation and refresh, permission denial/revocation, reduced accuracy, background/locked-screen voice, arrival, wrong-turn rerouting, lost connectivity, and saved-place persistence across updates.

Code is MIT licensed. Bundled font and style notices are staged into the app's **Settings → Licences and map attribution** screen. See the repository's [font notices](../docs/licenses/) and [privacy guide](../docs/guide.md#location-and-privacy).
