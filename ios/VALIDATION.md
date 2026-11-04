# iOS validation

This record covers the 0.2.0 preview and the contribution branch. Android's results in [the existing validation record](../docs/validation.md) apply to Android. Full Android/iOS behavioural parity has not been established.

## Checks completed locally

- All 26 `WaypointKit` XCTest cases pass. They cover routing-provider selection, response/geometry validation, voice/banner preparation, bundled-font HTTP responses, GPS retry decisions, destination parsing and iOS release selection.
- The unsigned arm64 device app builds with xtool 1.24.0 and Swift Build, using Command Line Tools and the iOS SDK from a user-folder Xcode installation.
- All 28 staged iOS styles pass the official MapLibre style validator. This includes the base style and the 27 world styles with their added POI layers.
- Package checks confirm iOS device Mach-O metadata, version/build values, MapLibre, the world catalogue and all 27 world styles, 324 POI tiles, world artwork/emblems, 17 UI fonts, motion resources and ZIP integrity.
- The published 0.2.0 IPA was downloaded again and matched its published SHA-256 checksum and the local build.
- All 27 HUDs were rendered with synthetic display state at regular phone, compact phone and landscape dimensions using macOS SwiftUI. The font checks confirm that all 17 UI fonts register. These renders assess layout; they do not exercise the iPhone map renderer, location provider or touch handling.
- The repository hygiene check passes. Generated apps, IPAs, local renders and logs stay outside tracked files.

Basic launch and map rendering were reported through LiveContainer on the earlier preview. That report predates the 0.2.0 themed UI. It does not establish fresh GPS acquisition, navigation or background behaviour for this version.

## Tests still to run

[NavigationContractTests.swift](WaypointTests/NavigationContractTests.swift) tests prepared route data against the actual Ferrostar parser. [WaypointUITests.swift](WaypointUITests/WaypointUITests.swift) covers onboarding, world selection, search/saved screens, settings and replay. Both suites are written, but neither has run in the current local toolchain. The GitHub workflow includes them; a workflow definition is not a successful test run.

Device checks are still needed for route guidance, speech interruptions, rerouting, arrival, map gestures, shared-link confirmation, saved-place persistence, locked-screen use and installer refresh. Use synthetic fixtures or fixed public landmarks. Do not publish personal routes, coordinates, device identifiers or unredacted captures.

## Reproducing checks

With a full Xcode installation selected, run the core tests and build the device app:

```sh
swift test --package-path ios/WaypointKit
bash scripts/build_ios.sh
python3 scripts/check_repo_hygiene.py
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
