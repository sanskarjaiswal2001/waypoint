"""Read the Android world catalogue without fixing its size to a release."""
import re
from pathlib import Path


def read_worlds(source):
    entries = re.findall(r'^\s*([A-Z][A-Z0-9_]*)\(', source, re.M)
    pattern = re.compile(
        r'([A-Z][A-Z0-9_]*)\("([^"]+)","([^"]+)",R\.string\.\w+,"([^"]+)",'
        r'Color\(0xFF([0-9A-Fa-f]{6})\),"(#[0-9A-Fa-f]{6})",Color\(0xFF([0-9A-Fa-f]{6})\)'
    )
    worlds = [dict(enum=enum, title=title, subtitle=subtitle, id=name, accentHex="#" + accent,
                   routeHex=route, groundHex="#" + ground)
              for enum, title, subtitle, name, accent, route, ground in pattern.findall(source)]
    if not worlds or [w["enum"] for w in worlds] != entries or len({w["id"] for w in worlds}) != len(worlds):
        raise ValueError("The Android world catalogue format changed or contains duplicate IDs")
    return worlds


def validate_worlds(root, worlds):
    root = Path(root)
    chrome = (root / "ios/Waypoint/AtlasChrome.swift").read_text().split("private var composition:", 1)[1].split("default:", 1)[0]
    treatments = set(re.findall(r'"([a-z_]+)"', chrome))
    missing = []
    for world in worlds:
        name = world["id"]
        for label, path in [
            ("map style", root / f"app/src/main/assets/styles/{name}.json"),
            ("globe texture", root / f"app/src/main/assets/globe/textures/{name}.png"),
        ]:
            if not path.is_file(): missing.append(f"{name}: missing {label}")
        emblems = [root / f"app/src/main/res/{folder}/world_emblem_{name}.{suffix}"
                   for folder, suffix in [("drawable-nodpi", "webp"), ("drawable-nodpi", "png"), ("drawable", "xml")]]
        if not any(path.is_file() for path in emblems): missing.append(f"{name}: missing emblem")
        if name not in treatments: missing.append(f"{name}: missing native phone HUD")
    if missing: raise ValueError("\n".join(missing))


def typefaces(root, worlds):
    root = Path(root)
    source = (root / "app/src/main/java/com/waypoint/app/WorldTypography.kt").read_text()
    fonts = dict(re.findall(r'^\s*(\w+)\(R\.font\.(\w+)', source, re.M))
    for role, function in [("titleTypeface", "titleTypeface"), ("readingTypeface", "readingTypeface")]:
        body = source.split(f'fun World.{function}()', 1)[1].split('}', 1)[0]
        mapping = {}
        for names, font in re.findall(r'((?:World\.\w+\s*,?\s*)+)->\s*WorldTypeface\.(\w+)', body):
            for name in re.findall(r'World\.(\w+)', names): mapping[name] = font
        fallback = re.search(r'else\s*->\s*WorldTypeface\.(\w+)', body).group(1)
        for world in worlds:
            font = fonts[mapping.get(world["enum"], fallback)]
            if not any((root / f"app/src/main/res/font/{font}.{extension}").is_file() for extension in ("ttf", "otf")):
                raise ValueError(f"{world['id']}: missing {role} font {font}")
            world[role] = font
