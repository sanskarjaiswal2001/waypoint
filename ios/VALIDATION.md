# iOS validation

This record covers the 0.3.0 contribution branch, compared with upstream Android 2.0.1 at `124e173`. Android's results in [the existing validation record](../docs/validation.md) apply to Android. Full Android/iOS behavioural parity has not been established.

## Checks completed locally

- All 66 `WaypointKit` XCTest cases pass. They cover routing profiles including Bicycle, bounded response/geometry validation, imperial speech, themed voice rules, font transport, GPS retry, heading/follow policies, imported-destination parsing and redirect limits, upstream release selection, saved-place naming and quest rewards/timers/persistence.
- The unsigned arm64 device app builds with xtool 1.24.0 and Swift Build, using Command Line Tools and the iOS SDK from a user-folder Xcode installation.
- All 39 staged iOS styles pass the official MapLibre style validator, including the base style and all 38 world styles with their added discovery layers.
- Five catalogue/font staging tests pass. They cover catalogue expansion, changed constructors, duplicate IDs, missing assets/HUDs and name-only Stratum normalization. No fixed count limits the catalogue. Font tests confirm glyph and licence tables are unchanged.
- The device package contains the 38-world catalogue, world styles, emblems/artwork, vehicle/voice metadata, 24 UI fonts, original POI atlases, motion resources and MapLibre. Packaging checks verify the iOS Mach-O platform, arm64 architecture, version metadata and ZIP integrity. Run the package verification command below on each release candidate.
- The earlier published 0.2.0 IPA was downloaded again and matched its published SHA-256 checksum and the local build. That result does not verify a 0.3.0 download.
- All 38 HUDs were rendered with synthetic display state at regular phone (390 × 760), compact phone (320 × 500) and landscape (780 × 320) dimensions using macOS SwiftUI. All 24 UI fonts register. These renders assess layout; they do not exercise the iPhone map renderer, location provider or touch handling.
- The repository hygiene check passes. Generated apps, IPAs, local renders and logs stay outside tracked files.

## Device report

On 5 November 2026, the device tester reported navigation working on an iPhone installed through LiveContainer with the earlier 0.2.0 preview. The supplied screenshots show the themed phone UI and rendered maps for Night City and Los Santos, with selected destinations and route preview controls. They are included in the [README](../README.md#ios-port-work-in-progress), with [capture and editing notes](../docs/images/ios/README.md).

The reported device is an iPhone 18 Pro on iOS 27.0.1, using LiveContainer. Its host version was not supplied. This is a user report without a recorded route or test checklist. The screenshots show destination selection rather than active guidance. They do not establish spoken output, rerouting, arrival, background use or full Android parity. No current-location capture was supplied. The 0.3.0 device checks remain pending.

## Tests still to run

[NavigationContractTests.swift](WaypointTests/NavigationContractTests.swift) tests prepared route data against the actual Ferrostar parser. [WorldResourceTests.swift](WaypointTests/WorldResourceTests.swift) checks fonts, artwork and transport image bounds. [WaypointUITests.swift](WaypointUITests/WaypointUITests.swift) covers onboarding, world selection, main panels, large-text route controls, Quests, saved-place renaming and relaunch persistence. These cannot run in the current local toolchain; native CI results must be recorded against the tested revision.

The earlier fork CI runs failed while waiting for an ARM runner. The workflow now uses the available Intel runner by default. A first Intel run reached the compiler and exposed a compass type-check timeout, which was fixed by splitting the view and drawing code. These failed or incomplete runs are not passing test evidence.

Repeatable device checks are still needed for route guidance, speech interruptions, rerouting, arrival, map gestures, shared-link confirmation, saved-place persistence, locked-screen use and installer refresh. Use synthetic fixtures or fixed public landmarks. Do not publish personal routes, coordinates, device identifiers or unredacted captures.

Use the [device checklist](DEVICE_CHECKS.md) for the new build. The [parity record](PARITY.md) lists the remaining Quests and platform differences.

## Reproducing checks

With a full Xcode installation selected, run the core tests and build the device app:

```sh
swift test --package-path ios/WaypointKit
bash scripts/build_ios.sh
python3 scripts/check_repo_hygiene.py
python3 -m unittest discover -s scripts -p 'test_ios_*.py'
python3 scripts/verify_ios_package.py ios/build/release/Waypoint-iOS-unsigned.ipa
```

The [build guide](README.md#swiftpm-and-xtool) also documents the xtool route used for the local IPA. Core XCTest execution requires the XCTest framework/runtime; Command Line Tools alone do not include it.

To run the native parser and UI suites, generate the project and select an available iPhone simulator:

```sh
python3 scripts/prepare_ios.py
xcodegen generate --spec ios/project.yml
xcodebuild test -project ios/Waypoint.xcodeproj -scheme Waypoint \
  -destination 'platform=iOS Simulator,name=<available iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO
```

For style validation, install the existing validator dependency and check the staged styles:

```sh
npm ci --prefix tools/style-validation
python3 scripts/prepare_ios.py
node - <<'JS'
const fs = require('node:fs');
const {validateStyleMin} = require('./tools/style-validation/node_modules/@maplibre/maplibre-gl-style-spec');
let failures = 0;
for (const name of fs.readdirSync('ios/Generated/styles').filter(name => name.endsWith('.json'))) {
  const errors = validateStyleMin(JSON.parse(fs.readFileSync(`ios/Generated/styles/${name}`, 'utf8')));
  for (const error of errors) console.error(`${name}: ${error.message}`);
  failures += errors.length;
}
console.log(`${failures} style errors`);
process.exitCode = failures ? 1 : 0;
JS
```

Record the command, result, source revision and test environment when adding evidence. Keep failures and tests that have not run visible in the record.
