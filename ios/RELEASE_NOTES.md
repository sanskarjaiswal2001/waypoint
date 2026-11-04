# Waypoint for iOS 0.2.0 — themed phone experience

The iOS phone UI now follows Android's world-specific atlas designs, replacing the simplified controls from the initial preview.

- Distinct HUD compositions for all 27 worlds, with the shared typefaces, colours, emblems, illustrations, compass designs and pixel toolbar.
- Original POI atlas icons, ranked discovery layers, tappable places, custom player/destination markers and an accuracy halo.
- Per-world camera defaults, persistent 2D/3D preference, walking/racing route treatments and a route line that follows remaining progress.
- Nearby search, route steps, speed, ETA and distance readouts, persistent spoken-guidance and imperial-unit settings, and confirmed history clearing.
- Animated introduction with the shared globe/icons and horse/phone artwork, multiple favourite games, world carousel, optional location setup and replay from Settings.
- Confirmed `geo:` and `google.navigation:` destinations, including links pasted into search. Existing guidance cannot be replaced by an import.
- Contextual GitHub feedback drafts, iOS release checks and idle-map update notices.
- Preserve the bundled-font HTTP transport fix and GPS freshness/recovery from 0.1.3.

## Install or update

Download **Waypoint-iOS-unsigned.ipa** and import it through the same LiveContainer container, SideStore or AltStore Classic installation. Keep the existing app identity/container to preserve saved places and settings. **SHA256SUMS-iOS** contains the download checksum. Requires iOS 17 or later.

The new themed map UI appears immediately. To see the new introduction on an existing installation, open **Settings → Replay introduction**.

## Validation

The unsigned arm64 device IPA was built with xtool 1.24.0 and Swift Build using the user-folder iOS SDK. All 26 core XCTest tests pass, including font transport, GPS recovery, destination imports and release selection. All staged iOS styles pass the official style validator. Package checks cover all worlds, their POI atlases, UI fonts, artwork, motion resources, frameworks, version metadata and ZIP integrity. All 27 HUDs received a local macOS SwiftUI layout review using synthetic display state; these previews do not establish iPhone rendering or real-road behaviour. Simulator UI tests are updated but have not been run. Device verification of the new phone UI and background navigation remains necessary.

## Platform scope

This is an experimental phone port. Android Auto, CarPlay, APK self-installation, Android GNSS satellite counts, a share extension and the default-navigation entitlement are outside this unsigned IPA. iOS supplies native sheets, permission dialogs, speech and lifecycle handling. Updates are installed through your existing installer. Maps, search and routing require online services; there is no traffic, offline routing or lane guidance.

See [phone parity and platform differences](https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.2.0/ios/PARITY.md) and [the installation guide](https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.2.0/ios/README.md).
