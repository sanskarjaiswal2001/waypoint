# Waypoint for iOS 0.1.1 — first IPA preview

Native SwiftUI app for iPhone and iPad running iOS 17 or later.

- All 27 shared map worlds, bundled map fonts and texture patterns.
- Photon destination search, dropped pins, saved places and recent destinations.
- Car, motorcycle and walking route previews using OSRM and Valhalla.
- Ferrostar turn progress, iOS spoken instructions, arrival and automatic rerouting.
- Location permission feedback, camera following, 2D/3D controls and world switching during a trip.

## Installation

Download **Waypoint-iOS-unsigned.ipa**, then import it with **SideStore** or **AltStore Classic** using **My Apps → +**. Your installer signs the app with your own account. This unsigned file cannot be installed directly from Files. Keep the app refreshed according to your installer's instructions. **SHA256SUMS-iOS** contains the download checksum.

See [the installation and build guide](https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.1.1/ios/README.md) for details.

## Build validation

The published unsigned arm64 IPA was compiled locally with xtool 1.24.0 and Swift Build, using the user-folder iOS SDK. The package was checked for iOS device Mach-O metadata, required frameworks and map resources, and ZIP integrity. All 11 XCTest routing adapter tests passed, along with live public-landmark search/car/motorcycle/walking route checks. Simulator UI tests have not been run for this build.

## Preview limits

This is an experimental iOS port. Physical-device installation, background guidance and real-road behaviour still need validation. It requires online map/search/routing services and has no traffic, offline routing or lane guidance. CarPlay, incoming destination links, the Android updater, onboarding videos and per-game Android HUD layouts are not included. This release is separate from the upstream Android stable releases.
