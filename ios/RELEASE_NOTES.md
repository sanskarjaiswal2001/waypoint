# Waypoint for iOS 0.3.0

This preview follows upstream Android 2.0.1 and expands the port to 38 worlds.

- Eleven added phone HUDs, with shared typography, vector emblems and world artwork. Vehicle markers follow the selected travel mode and world's livery.
- Bicycle routing through Valhalla, a retained travel mode, saved-place renaming and automatic camera-follow recovery after gestures during navigation.
- Search ranking, typo matching, local saved/recent matches, a memory cache and Apple's address fallback when Photon finds no strong result.
- Quests on every idle HUD, with local tasks, linked places, explicit completion, Undo, XP and a focus timer. Arrival never completes a task. Photos, quest alerts and the full Android reward presentation are still absent.
- Confirmed coordinate/address imports and supported Google Maps links, bounded short-link resolution, destination sharing and a Google Maps handoff.
- Themed speech and generated prompts in the selected units, plus guidance thresholds aligned with Android's active Ferrostar configuration.
- What's New after an update, upstream update/feedback destinations and scrollable route content with the primary action kept visible.

## Install or update

Requires iOS 17 or later. Download Waypoint-iOS-unsigned.ipa and import it through the same LiveContainer container, SideStore or AltStore Classic installation. Keep the existing identity/container to retain saved places and settings. Check the download against SHA256SUMS-iOS.

The app checks the upstream repository's ios-v* releases. Contribution previews on the fork are separate downloads and do not become upstream updates.

## Validation and remaining work

Core tests cover search, routing profiles, imports, heading/follow policies, speech, preferences and quest rewards/timers. Catalogue and font staging checks cover every world. The unsigned device build and local macOS layout renders do not establish physical-device behavior.

Native parser/resource and simulator UI results are recorded in [iOS validation](VALIDATION.md). Controlled iPhone checks for speech, wrong-turn recovery, arrival, permission changes, locked/background use and update persistence remain required before merge. The screenshots and reported navigation result in the README come from the earlier 0.2.0 preview.

See the [feature comparison](PARITY.md) for implementation status and deliberate platform differences.
