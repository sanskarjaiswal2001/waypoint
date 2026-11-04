# Waypoint for iOS 0.1.2 — GPS recovery

Native SwiftUI preview for iPhone and iPad running iOS 17 or later.

- Keep foreground GPS updates running when stationary instead of allowing automatic pauses or suppressing small movements.
- Restart location acquisition when returning to the app, including when no initial fix has arrived.
- Recover stalled location streams with throttled retries. Tapping **Locate** explicitly restarts acquisition.
- Continue rejecting cached, invalid and out-of-order fixes. Route preview and navigation still require a fresh, accurate position.
- Explain host location permissions for LiveContainer in permission feedback and the installation guide.
- Load the selected bundled map style directly when creating the map. Show map-loading failures separately from GPS warnings, with a **Retry map** action and a loading timeout.

## Installation

Download **Waypoint-iOS-unsigned.ipa**, then import it with **SideStore**, **AltStore Classic** or your existing LiveContainer setup. Use the same app identity/container when updating to preserve local saved places. **SHA256SUMS-iOS** contains the download checksum.

For LiveContainer, check **iOS Settings → Privacy & Security → Location Services → LiveContainer** (the instance hosting Waypoint). Allow **While Using the App** and enable **Precise Location**, then reopen Waypoint and tap **Locate**. A new GPS reading may take time; an old position is never relabeled fresh simply to clear the warning.

See [the installation and build guide](https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.1.2/ios/README.md) for details.

## Build validation

The unsigned arm64 IPA was compiled locally with xtool 1.24.0 and Swift Build using the user-folder iOS SDK. The package was checked for iOS device Mach-O metadata, required frameworks and map resources, and ZIP integrity. All 17 core XCTest tests passed, including six location freshness and recovery regressions. Simulator UI tests have not been run for this build. GPS recovery and map rendering still require device verification, including LiveContainer hosting and background guidance.

## Preview limits

This is an experimental iOS port. Background guidance and real-road behaviour still need validation. It requires online map/search/routing services and has no traffic, offline routing or lane guidance. CarPlay, incoming destination links, the Android updater, onboarding videos and per-game Android HUD layouts are not included. This release is separate from the upstream Android stable releases.
