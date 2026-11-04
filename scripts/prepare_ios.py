#!/usr/bin/env python3
"""Stage shared Android cartography and licence notices for the native iOS target."""

import json
import plistlib
from pathlib import Path
import re
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ios/Generated"
DEST.mkdir(parents=True, exist_ok=True)
assets = ROOT / "app/src/main/assets"
for directory in ("styles", "glyphs"):
    target = DEST / directory
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(assets / directory, target)

source = (ROOT / "app/src/main/java/com/waypoint/app/World.kt").read_text()
pattern = re.compile(
    r'\w+\("([^"]+)","([^"]+)",R\.string\.\w+,"([^"]+)",'
    r'Color\(0xFF([0-9A-Fa-f]{6})\),"(#[0-9A-Fa-f]{6})",Color\(0xFF([0-9A-Fa-f]{6})\)'
)
worlds = [dict(title=title, subtitle=subtitle, id=name, accentHex="#" + accent,
               routeHex=route, groundHex="#" + ground)
          for title, subtitle, name, accent, route, ground in pattern.findall(source)]
if len(worlds) != 27 or len({world["id"] for world in worlds}) != len(worlds):
    raise SystemExit("World catalogue changed; review the iOS staging parser")
for world in worlds:
    if not (DEST / "styles" / (world["id"] + ".json")).is_file():
        raise SystemExit("Missing style for " + world["id"])
(DEST / "worlds.json").write_text(json.dumps(worlds, indent=2) + "\n")

patterns = DEST / "patterns"
patterns.mkdir(exist_ok=True)
for name in ("paper_fibre", "pixel_grass", "pixel_stone", "pixel_water"):
    shutil.copyfile(ROOT / "app/src/main/res/drawable-nodpi" / (name + ".png"), patterns / (name.replace("_", "-") + ".png"))

catalog = DEST / "Assets.xcassets"
catalog.mkdir(exist_ok=True)
(catalog / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}))
icon = ROOT / "docs/images/waypoint-icon.png"
shutil.copyfile(icon, DEST / "WaypointMark.png")
for name, metadata in (
    ("WaypointMark.imageset", {"images": [{"filename": "icon.png", "idiom": "universal"}]}),
    ("AppIcon.appiconset", {"images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]})
):
    folder = catalog / name
    folder.mkdir(exist_ok=True)
    shutil.copyfile(icon, folder / "icon.png")
    if name == "AppIcon.appiconset":
        subprocess.run(["sips", "-z", "1024", "1024", str(folder / "icon.png")], check=True, capture_output=True)
    metadata["info"] = {"version": 1, "author": "xcode"}
    (folder / "Contents.json").write_text(json.dumps(metadata, indent=2) + "\n")

notices = ["Waypoint\n\n" + (ROOT / "LICENSE").read_text(),
           "Map data © OpenStreetMap contributors (ODbL). https://www.openstreetmap.org/copyright\n"
           "Map tiles: OpenFreeMap. https://openfreemap.org\n"
           "Terrain: Mapzen / Tilezen. https://www.mapzen.com/rights/\n"
           "MapLibre Native: BSD 2-Clause. https://github.com/maplibre/maplibre-native\n"
           "Ferrostar: BSD 3-Clause. https://github.com/stadiamaps/ferrostar\n"]
for path in sorted((ROOT / "docs/licenses").iterdir()) + sorted((ROOT / "ios/ThirdPartyLicenses").iterdir()):
    if path.is_file():
        notices.append(path.name + "\n\n" + path.read_text())
(DEST / "notices.txt").write_text("\n\n---\n\n".join(notices))

project = (ROOT / "ios/project.yml").read_text()
version = re.search(r"MARKETING_VERSION:\s*([0-9.]+)", project).group(1)
build = re.search(r"CURRENT_PROJECT_VERSION:\s*([0-9]+)", project).group(1)
with (ROOT / "ios/Waypoint/Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
info.update({
    "CFBundleDevelopmentRegion": "en", "CFBundleExecutable": "Waypoint",
    "CFBundleIdentifier": "org.waypoint.ios", "CFBundleName": "Waypoint",
    "CFBundleShortVersionString": version, "CFBundleVersion": build,
    "CFBundleSupportedPlatforms": ["iPhoneOS"], "MinimumOSVersion": "17.0",
    "UIDeviceFamily": [1, 2],
})
with (DEST / "Info-xtool.plist").open("wb") as stream:
    plistlib.dump(info, stream)
print(f"Staged {len(worlds)} worlds, bundled glyphs, patterns and notices in ios/Generated")
