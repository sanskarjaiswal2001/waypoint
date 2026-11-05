#!/usr/bin/env python3
"""Stage shared Android cartography and licence notices for the native iOS target."""

import json
import plistlib
from pathlib import Path
import re
import shutil
import subprocess
from ios_cartography import add_discovery_layers
from ios_catalogue import read_worlds, validate_worlds, typefaces, palettes
from ios_fonts import normalize_stratum


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
worlds = read_worlds(source)
validate_worlds(ROOT, worlds)
typefaces(ROOT, worlds)
palettes(ROOT, worlds)
cartography = (ROOT / "app/src/main/java/com/waypoint/app/Cartography.kt").read_text()
map_art = {name: dict(tilt=float(tilt), zoom=float(zoom), routeWidth=float(width), poiScale=float(scale), marker=marker, player=player, lightLabels=light == "true")
           for name, tilt, zoom, width, scale, marker, player, light in re.findall(
               r'World\.(\w+)->MapArt\(([.0-9]+),([.0-9]+),([.0-9]+)f,([.0-9]+)f,MarkerArt\.(\w+),PlayerArt\.(\w+),(true|false)\)', cartography)}
vehicle_source = (ROOT / "app/src/main/java/com/waypoint/app/VehicleMarkers.kt").read_text()
vehicles = {name: dict(car=car, bike=bike, body=body, trim=trim, pixel="pixel=true" in flags, wire="wire=true" in flags)
            for name, car, bike, body, trim, flags in re.findall(
                r'World\.(\w+) -> VehicleLivery\(WorldTransport\.(\w+),WorldTransport\.(\w+),"(#[A-Fa-f0-9]+)","(#[A-Fa-f0-9]+)"([^)]*)\)', vehicle_source)}
voice_source = (ROOT / "app/src/main/java/com/waypoint/app/WorldVoice.kt").read_text()
voices = {name: dict(openings=[opening], cues=[cue], arrivals=[arrival], rate=float(rate), pitch=float(pitch))
          for name, opening, cue, arrival, pitch, rate in re.findall(
              r'World\.(\w+) -> WorldVoiceStyle\("([^"]*)","([^"]*)","([^"]*)",([.0-9]+)f,([.0-9]+)f\)', voice_source)}
lines_source = (ROOT / "app/src/main/java/com/waypoint/app/WorldVoiceLines.kt").read_text()
for name, body in re.findall(r'World\.(\w+) -> style\.withLines\((.*?)\)', lines_source, re.S):
    lines = re.findall(r'"([^"]*)"', body)
    if name not in voices or len(lines) != 6: raise SystemExit("Review voice lines for " + name)
    for index, key in enumerate(("openings", "cues", "arrivals")): voices[name][key] += lines[index * 2:index * 2 + 2]
for world in worlds:
    name = world["enum"]
    if name not in vehicles or name not in voices: raise SystemExit("Missing vehicle or voice treatment for " + name)
    world["vehicle"] = vehicles[name]
    world["voice"] = voices[name]
    if name not in map_art: raise SystemExit("Missing map treatment for " + name)
    world["mapArt"] = map_art[name]
for world in worlds:
    if not (DEST / "styles" / (world["id"] + ".json")).is_file():
        raise SystemExit("Missing style for " + world["id"])
    style_path = DEST / "styles" / (world["id"] + ".json")
    style = json.loads(style_path.read_text())
    add_discovery_layers(style, world["id"], world["mapArt"]["poiScale"], world["mapArt"]["lightLabels"])
    style_path.write_text(json.dumps(style, separators=(",", ":")))
(DEST / "worlds.json").write_text(json.dumps(worlds, indent=2) + "\n")

for directory, origin in (("fonts", ROOT / "app/src/main/res/font"), ("motion", ROOT / "app/src/main/res/raw")):
    target = DEST / directory
    if target.exists():
        shutil.rmtree(target)
    if directory == "motion":
        target.mkdir()
        for name in ("onboarding_globe_motion.mp4", "onboarding_icons_motion.mp4"):
            shutil.copyfile(origin / name, target / name)
    else:
        shutil.copytree(origin, target)
for name in ("stratum2_regular.ttf", "stratum2_bold.ttf"):
    normalize_stratum(DEST / "fonts" / name)
subprocess.run(["swift", str(ROOT / "scripts/prepare_ios_art.swift"), str(ROOT)], check=True)

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
