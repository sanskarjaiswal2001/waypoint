"""Check staged world and font coverage in an unsigned iOS package."""
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path
from ios_catalogue import read_worlds, validate_worlds

ROOT = Path(__file__).resolve().parents[1]


def verify(path):
    worlds = read_worlds((ROOT / "app/src/main/java/com/waypoint/app/World.kt").read_text())
    validate_worlds(ROOT, worlds)
    with zipfile.ZipFile(path) as package:
        if package.testzip() is not None: raise ValueError("Invalid ZIP data")
        prefix = "Payload/Waypoint.app/"
        names = set(package.namelist())
        info = plistlib.loads(package.read(prefix + "Info.plist"))
        project = (ROOT / "ios/project.yml").read_text()
        version = re.search(r'MARKETING_VERSION:\s*([0-9.]+)', project).group(1)
        build = re.search(r'CURRENT_PROJECT_VERSION:\s*([0-9]+)', project).group(1)
        if (info["CFBundleShortVersionString"], info["CFBundleVersion"]) != (version, build): raise ValueError("Version metadata differs from project")
        bundled = json.loads(package.read(prefix + "worlds.json"))
        if [w["id"] for w in bundled] != [w["id"] for w in worlds]: raise ValueError("Incomplete world catalogue")
        for world in bundled:
            key = world["id"]
            for name in [f"styles/{key}.json", f"ui/world_emblem_{key}.png"]:
                if prefix + name not in names: raise ValueError("Missing " + name)
            if not any(prefix + f"ui/art_{key}.{extension}" in names for extension in ("jpg", "png")): raise ValueError("Missing artwork for " + key)
            if not world.get("voice") or not world.get("vehicle") or not world.get("mapArt"): raise ValueError("Missing world treatment for " + key)
        fonts = json.loads(package.read(prefix + "font-names.json"))
        if len(set(fonts.values())) != len(fonts): raise ValueError("Colliding font names")
        for font in (ROOT / "ios/Generated/fonts").iterdir():
            if package.read(prefix + "fonts/" + font.name) != font.read_bytes(): raise ValueError("Bundled font differs from staged font")
        for world in bundled:
            for role in ("titleTypeface", "readingTypeface"):
                if world.get(role) not in fonts: raise ValueError("Missing world font: " + world["id"])
        if any("_CodeSignature/" in name or name.endswith("embedded.mobileprovision") for name in names): raise ValueError("Unexpected signing material")
        if prefix + "Frameworks/MapLibre.framework/MapLibre" not in names: raise ValueError("Missing MapLibre")
        print(f"Verified iOS {version} ({build}): {len(worlds)} worlds, {len(fonts)} fonts, artwork, voices, vehicles and ZIP integrity")


if __name__ == "__main__": verify(Path(sys.argv[1]))
