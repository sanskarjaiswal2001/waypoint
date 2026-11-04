#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
python3 scripts/prepare_ios.py
xcodegen generate --spec ios/project.yml
resolution=ios/Waypoint.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$resolution"
cp ios/Package.resolved "$resolution/Package.resolved"

derived="$PWD/ios/build/DerivedData"
xcodebuild -project ios/Waypoint.xcodeproj -scheme Waypoint -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$derived" \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

python3 scripts/package_ios.py "$derived/Build/Products/Release-iphoneos/Waypoint.app" ios/build/release
