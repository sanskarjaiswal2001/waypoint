#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root="$PWD"

xtool_bin="${WAYPOINT_XTOOL:-xtool}"
xcode_app="${WAYPOINT_XCODE_APP:-$HOME/Applications/Xcode.app}"
command -v "$xtool_bin" >/dev/null || { echo 'Set WAYPOINT_XTOOL to the xtool executable'; exit 1; }
test -d "$xcode_app/Contents/Developer/Platforms/iPhoneOS.platform" || {
  echo 'Set WAYPOINT_XCODE_APP to an Xcode app containing the iOS SDK'
  exit 1
}

python3 scripts/prepare_ios.py

# Add the iOS platforms alongside the active host tools, avoiding duplicate macOS platforms.
platforms="$project_root/ios/build/xtool-platforms"
mkdir -p "$platforms"
for platform in iPhoneOS iPhoneSimulator; do
  source_platform="$xcode_app/Contents/Developer/Platforms/$platform.platform"
  if test -d "$source_platform"; then
    ln -sfn "$source_platform" "$platforms/$platform.platform"
  fi
done

export DEVELOPER_DIR="${WAYPOINT_HOST_DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
export XCODE_EXTRA_PLATFORM_FOLDERS="$platforms"
export XTL_CLI=1
cd ios
"$xtool_bin" dev build --configuration release
cd "$project_root"
python3 scripts/package_ios.py ios/xtool/Waypoint.app ios/build/release
