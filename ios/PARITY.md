# iOS port status

The iOS port is under development, and the Android parity audit is still in progress. The table distinguishes implemented code from behaviour checked on a device.

The comparison uses the Android source at `b3e044d` and the iOS 0.2.0 preview. The README's promotional screenshots show Android, including Android Auto. iOS device screenshots are still needed.

## Feature comparison

| Area | iOS implementation | Verification and remaining work |
| --- | --- | --- |
| Worlds and phone HUDs | SwiftUI layouts for all 27 worlds, with shared fonts, colours, emblems, artwork, compass treatments and the pixel toolbar. | The asset checks and macOS layout renders cover all 27. Actual iPhone layout, touch targets and accessibility still need review. See [AtlasChrome.swift](Waypoint/AtlasChrome.swift) and [WorldTheme.swift](Waypoint/WorldTheme.swift). |
| Map rendering and markers | Shared MapLibre styles and glyphs, POI atlases, ranked discovery layers, player/destination markers and an accuracy halo. | All 28 staged styles pass validation. The package includes the assets for every world. Basic map rendering was reported through LiveContainer on the earlier preview; the new marker layers still need device checks. |
| Search | Photon lookup with a nearby position bias and duplicate removal. Nearby buttons submit category queries. | Partial. Android also has result ranking, spelling aliases, a search cache and an Android Geocoder fallback. Those behaviours are absent from [MapService.swift](WaypointKit/Sources/WaypointKit/MapService.swift). |
| Place selection | Search results, long-press pins and selectable map POIs. | Implemented in [Panels.swift](Waypoint/Panels.swift) and [WorldMap.swift](Waypoint/WorldMap.swift). Map taps and category coverage still need device checks. |
| Saved and recent places | Local storage, selection, deletion and confirmation before clearing history. | Implemented. The simulator test covers opening the saved screen, but has not run. Persistence across app updates and process restarts still needs checking. |
| Route previews | Car routes use OSRM; motorcycle and walking routes use distinct Valhalla profiles. Route preparation validates geometry and endpoints. | Core tests cover provider selection and route preparation. Live public-landmark requests worked during the earlier build. The separate native Ferrostar parser test has not run. |
| Guidance | Ferrostar progress, turn instructions, remaining route geometry, ETA/distance, arrival handling and rerouting callbacks. | Implemented. Controlled journeys, wrong turns, arrival and provider outages have not been verified on an iPhone. Android's reroute timing and recovery policies need comparison. |
| Voice | Ferrostar's iOS speech observer and a persistent voice preference. | Spoken output, interruptions and recovery need device testing. Android's `GuidanceVoice` startup/recovery wrapper has no direct iOS equivalent in this port. |
| Camera following | Follow, manual Locate, world-specific zoom/tilt and route framing. | Partial. A pan disables iOS following until Locate is tapped. Android resumes following after eight seconds during navigation. |
| Location and heading | Core Location updates, freshness checks, retry watchdog, course/compass selection, accuracy and speed readouts. | Watchdog logic has unit tests. Permission changes, stationary fixes, calibration and movement still need device checks. Android's heading arbitration and GNSS/provider fallback policies have not been reproduced. |
| Preferences | World, favourites, voice, distance units and tilt persist locally. | Partial. The travel mode starts as Car on each launch; Android retains the previous mode. |
| Onboarding | Shared globe/icon motion, horse/phone artwork, referral selection, multiple favourites, a world carousel and optional location setup. Motion pauses when inactive and respects Reduce Motion. | Implemented with native iOS presentation. The full flow and replay test are written but have not run in the simulator. The horse animation adapts Android's bitmap mesh to native drawing. |
| Shared destinations | Validated `geo:` and `google.navigation:` proposals, pasted-link support, confirmation and an active-trip guard. | Parser tests pass. Confirmation presentation and external dispatch need device checks, including LiveContainer hosting. A share extension and default-navigation entitlement are absent. |
| Feedback | A form opens a GitHub draft with feedback type, world and app version for the user to review. | Implemented. Browser handoff has not been checked. The preview uses the fork's issue tracker. |
| Updates | iOS release checks and an idle-map notice that opens the release page. | Release-selection tests pass. Signing and installation stay with the user's installer. Android's APK verification/installation and What's New flow are not ported. |
| Background use | Location/audio background modes and navigation lifecycle handling. | Configured. Locked-screen guidance, suspension, battery use and long sessions remain unverified. |
| Car display | No car display integration in this IPA. | Android Auto is platform specific. CarPlay would require separate work and [Apple-approved entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements). |

## Testing priorities

- Run the native route-parser test and simulator UI suite on a full Xcode installation.
- Capture iPhone screenshots at fixed public demonstration coordinates and compare the layouts with Android.
- Exercise permission denial/revocation, reduced accuracy, stale fixes, heading changes and return from the background.
- Check route preview, spoken turns, rerouting, arrival and loss of connectivity on controlled journeys.
- Test saved-place persistence, onboarding replay and shared destinations across app restarts.
- Decide which search, camera-follow and preference differences should be ported before calling the phone behaviour equivalent.

[Validation details](VALIDATION.md) distinguish local checks, reported device behaviour and work still to run. Private captures and logs stay out of Git and releases.
