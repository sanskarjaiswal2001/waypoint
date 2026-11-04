# Waypoint for iOS 0.1.3 — bundled font transport

Native SwiftUI preview for iPhone and iPad running iOS 17 or later.

- Fix bundled map fonts being returned as generic URL responses. MapLibre's HTTPS transport requires HTTP responses; font blocks now return HTTP 200 with their original bytes, content type and length.
- Bypass the URL cache for map requests so previously cached invalid font responses cannot be reused. Bundled fonts remain local.
- Replace the generic connection warning with loading-stage messages. A timeout identifies whether the style, renderer or map resources are still pending; actual map-loader errors retain their own descriptions.
- Include the GPS freshness and recovery changes from 0.1.2.

## Installation

Download **Waypoint-iOS-unsigned.ipa** and update through your existing LiveContainer, SideStore or AltStore Classic setup. Keep the same app identity/container to preserve saved places. **SHA256SUMS-iOS** contains the download checksum.

Reopen Waypoint and allow the map to load before tapping **Locate**. If it remains blank after 25 seconds, note the exact loading-stage message. For LiveContainer, enable location access and **Precise Location** for the instance hosting Waypoint.

See [the installation and build guide](https://github.com/sanskarjaiswal2001/waypoint/blob/ios-v0.1.3/ios/README.md) for details.

## Build validation

The unsigned arm64 IPA was compiled locally with xtool 1.24.0 and Swift Build using the user-folder iOS SDK. Package checks cover device Mach-O metadata, required frameworks, bundled map resources and ZIP integrity. All 20 core XCTest tests passed. The new font transport regression failed with the original generic response and passed with the HTTP response. Simulator UI tests have not been run. Map rendering and GPS recovery still require device verification, including LiveContainer hosting and background guidance.

## Preview limits

This is an experimental iOS port. Background guidance and real-road behaviour still need validation. Online map/search/routing services are required. Traffic, offline routing, lane guidance, CarPlay, incoming destination links, the Android updater, onboarding videos and per-game Android HUD layouts are not included. This release is separate from the upstream Android stable releases.
