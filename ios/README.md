# Waypoint for iOS

A native SwiftUI port for iPhone and iPad on iOS 17 or later. Development and Android parity checks are ongoing. The app shares Android's 27 MapLibre styles, map fonts, patterns and online providers, with Ferrostar 0.59.0 for guidance.

[Upstream issue #12](https://github.com/the-geeky-couldron/waypoint/issues/12) tracks the port and remaining work.

The source includes themed phone HUDs, POI layers, onboarding, search, route controls, saved places and preferences. Read the [feature comparison](PARITY.md) for partial implementations and missing Android behaviours. The [validation record](VALIDATION.md) lists completed checks and tests that still need to run.

This is an experimental preview. Navigation is reported working through LiveContainer, and [device screenshots](../docs/images/ios/README.md) show the Night City and Los Santos phone UI. GPS edge cases, speech and background guidance still need repeatable device checks. CarPlay, Android's APK installer and satellite counts are outside this port. The GitHub README's promotional artwork shows Android; its iOS section contains the device screenshots.

## Install through SideStore or AltStore Classic

1. Set up [SideStore](https://docs.sidestore.io/docs/installation/install) or [AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore) using its official instructions. Enable Developer Mode on the device if the installer requests it.
2. Open this fork's [Releases](https://github.com/sanskarjaiswal2001/waypoint/releases) and download **Waypoint-iOS-unsigned.ipa** from an iOS preview release to Files on your device.
3. In SideStore or AltStore Classic, open **My Apps**, tap **+**, and choose the downloaded IPA. The installer signs it with your account and installs it.
4. Open Waypoint, choose a world and tap **Open map**. Tap **Locate**, allow location access with **Precise Location** enabled, then search for a destination or hold the map to drop a pin.
5. Choose Car, Motorcycle or Walk, tap **Preview route**, and review it before starting navigation.

An existing installation opens directly into the new themed HUD. Use **Settings → Replay introduction** to see the expanded onboarding. Each world arranges Search, Worlds, Saved, Settings, Locate and map tilt differently. The introduction supports multiple favourite games and keeps those preferences on the device.

To open a shared `geo:` or `google.navigation:` destination, paste it into **Search places** and tap **Open shared destination**. Review the confirmation before allowing a lookup or route preview. Direct external dispatch depends on your installer/LiveContainer host. An import never replaces active guidance. Updates appear as release links; install the newer IPA through your existing installer.

The IPA is unsigned and cannot be installed by tapping it directly in Files. It contains one arm64 device app, no app extensions and no restricted CarPlay entitlement. SideStore/AltStore handles signing and refresh. Free-account signatures normally need refreshing within seven days; follow the installer's current guidance and account limits. AltStore PAL is a different distribution system and does not use the IPA-import route described here.

LiveContainer can also import the IPA. Navigation is reported working there, with device captures of the themed maps and destination controls. See the [validation record](VALIDATION.md#device-report) for the report's scope and remaining checks. Keep the same app container when updating to retain local data, and manage location permission on the LiveContainer instance hosting Waypoint.

For updates, import the newer IPA using the same installer, account and app identity. Avoid deleting the existing app if you want to keep its saved places. Checksums are published in **SHA256SUMS-iOS**:

```sh
shasum -a 256 -c SHA256SUMS-iOS
```

## Location troubleshooting

If the position becomes stale, tap **Locate** to restart location acquisition. Keep the app in the foreground and allow time for a precise fix with a clear view of the sky. A cached position stays marked stale until a new reading arrives; route preview and navigation still require a fresh, accurate fix.

Map loading uses an independent connection to the tile provider. If the map is blank, wait for the loading message and tap **Retry map**. Map errors are shown separately from GPS warnings, so a location issue cannot hide a map-loading failure. Check connectivity to `tiles.openfreemap.org` if loading fails across all worlds.

When running inside **LiveContainer**, check **iOS Settings → Privacy & Security → Location Services → LiveContainer** (or the specific LiveContainer instance hosting the app). Allow **While Using the App** and enable **Precise Location**, then reopen Waypoint and tap **Locate**. Guest apps share the host's permissions; see [LiveContainer's permission discussion](https://github.com/LiveContainer/LiveContainer/issues/401). Background location while hosted still needs separate device validation. A direct SideStore/AltStore installation can help distinguish host-specific behavior.

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

The iOS workflow is configured to run core tests, compile a Release device build and run the native parser/UI suites on a macOS runner. Branch builds upload the IPA as a workflow artifact. An `ios-v*` tag publishes an iOS prerelease after the build job passes. This tag prefix keeps iOS releases separate from the Android stable update channel. Check the actual run status before treating CI as validation; the workflow file alone is not a test result.

Before tagging, update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `ios/project.yml` and review `ios/RELEASE_NOTES.md`. Commit the resolved Swift package file when dependencies change; the build stages it into the generated project before resolving packages.

## Privacy, services and validation

- Map tiles and labels: OpenFreeMap / OpenStreetMap; terrain: Mapzen.
- Place search: Photon. The query and optional nearby position are sent to the service.
- Car routes: OSRM. Motorcycle and walking routes: Valhalla using their distinct costing profiles.
- Guidance: Ferrostar on-device, with iOS text-to-speech and Core Location.
- Saved places, recent destinations and selected world: local app preferences. No account or analytics service.
- City label: Core Location reverse geocoding. Release checks: the fork's public GitHub releases, without location data.

Location is requested only after **Locate** or an explicit route preview. Background location is enabled only while navigating. Ending a trip releases background location and the screen-awake state. The map can be browsed without granting location. Search needs no GPS fix, while route preview and navigation require a recent position with adequate accuracy. Online providers can be unavailable or rate-limited. There is no offline routing, live traffic or lane guidance.

Core tests cover provider selection, coordinate order, malformed responses, bounded geometry, upcoming-turn prompts, font transport, GPS recovery, destination imports and release selection. A compiled IPA does not establish real-road safety or installation compatibility. Before expanding the release beyond a preview, validate on a physical device: the themed layouts and map gestures, installation and refresh, permission denial/revocation, reduced accuracy, background/locked-screen voice, arrival, wrong-turn rerouting, lost connectivity, and saved-place persistence across updates.

Code is MIT licensed. Bundled font and style notices are staged into the app's **Settings → Licences and map attribution** screen. See the repository's [font notices](../docs/licenses/) and [privacy guide](../docs/guide.md#location-and-privacy).
