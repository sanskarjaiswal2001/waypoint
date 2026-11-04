# Android phone experience on iOS

The GitHub README artwork shows the Android app, including its Android Auto screens. iOS 0.1.x shared the map styles and navigation core but used a simpler interface. The 0.2.0 phone port brings over the themed atlas controls and the following phone features.

| Area | iOS implementation |
| --- | --- |
| World HUDs | Distinct compositions for all 27 worlds, based on `GameAtlasHud.kt`, `FantasyAtlases.kt` and `ModernAtlases.kt`. Shared colours, title/body fonts, framed panels, compass treatments, pixel toolbar and nearby actions. |
| Cartography | Shared vector styles, bundled glyphs and textures; all 27 original POI atlases; ranked discovery layers; themed player, uncertain-position and destination markers; accuracy halo; per-world camera defaults and route treatments. |
| Discovery | Photon search, nearby categories, selectable map POIs, long-press pins, saved destinations and recent trips. |
| Routes | Car, motorcycle and walk; route preview, ETA/distance, step list, remaining route line, spoken turns, arrival, deviation feedback and rerouting. |
| Sensors | Core Location accuracy/freshness feedback; course or compass heading; live compass, speed readout, recenter and persistent 2D/3D preference. Invalid or stale positions do not become ready fixes. |
| Preferences | Persistent voice and distance units, selected world, multiple favourite worlds, saved places and recent history; confirmation before clearing places. |
| Onboarding | Shared globe/icon motion, horse/phone artwork, referral selection, multiple favourites, world carousel and optional location setup. Introduction can be replayed. Motion pauses when inactive and respects Reduce Motion. |
| Shared destinations | `geo:` and `google.navigation:` parsing with coordinate validation and confirmation. Links can also be pasted into search. Imports cannot replace an active trip. |
| Feedback | GitHub draft with feedback type, selected world and app version, reviewed in the browser before submission. No location or route is attached. |
| Releases | iOS preview checks, idle-map update notice and release links. The existing installer handles signing and installation. |

## Platform differences

- Android Auto is an Android integration. CarPlay is outside the phone port and requires an [Apple-approved navigation entitlement and provisioning](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements); it is not included in the unsigned IPA.
- Android's signed APK updater cannot install an IPA. iOS opens the appropriate release for installation through LiveContainer, SideStore or AltStore.
- Android's satellite counts, fused-provider selection and sensor descriptions are replaced by Core Location status, accuracy and heading. The current city label uses Core Location reverse geocoding.
- Apple supplies the speech engine, permission dialogs, keyboard, navigation sheets and sharing dispatch. SwiftUI adapts the layouts to safe areas and compact orientation; the decorative horse motion uses native drawing rather than Android's bitmap mesh.
- LiveContainer owns host permissions and external-link dispatch. In-app pasted links work without registering Waypoint as the device's default map handler. A share extension and default-navigation entitlement are not included.

## Validation boundary

The iOS device build and core tests establish compilation and adapter behaviour. All 27 atlas compositions were also rendered locally for a macOS SwiftUI layout review with synthetic display state; these are layout previews, not iPhone screenshots or evidence of real-road behaviour. Simulator UI tests are updated for onboarding, world selection, search, saved places and settings, but have not been executed in the current local toolchain. Device checks are still required for actual layout, gestures, speech, background guidance and LiveContainer behaviour.

Keep private QA captures and logs out of Git and releases. Use synthetic coordinates or fixed public landmarks for reproducible checks.
