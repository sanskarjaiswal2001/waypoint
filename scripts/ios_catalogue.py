"""Read the Android world catalogue without fixing its size to a release."""
import re
import json
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
    if not worlds or [w["enum"] for w in worlds] != entries or len({w["id"] for w in worlds}) != len(worlds) or any(not re.fullmatch(r'[a-z][a-z0-9_]*', w["id"]) for w in worlds):
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
        style_path = root / f"app/src/main/assets/styles/{name}.json"
        if style_path.is_file():
            for layer in json.loads(style_path.read_text()).get("layers", []):
                for font in layer.get("layout", {}).get("text-font", []):
                    if not isinstance(font, str) or not (root / "app/src/main/assets/glyphs" / font / "0-255.pbf").is_file():
                        missing.append(f"{name}: missing bundled glyphs for {font}")
                for key, value in layer.get("paint", {}).items():
                    if key.endswith("-pattern") and isinstance(value, str) and not (root / "app/src/main/res/drawable-nodpi" / (value.replace("-", "_") + ".png")).is_file():
                        missing.append(f"{name}: missing pattern {value}")
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


def palettes(root, worlds):
    source = (Path(root) / "app/src/main/java/com/waypoint/app/GameHud.kt").read_text()
    block = source.split("fun hudPalette(world:World)=when(world)", 1)[1].split("\n}", 1)[0]
    mapping, fallback = {}, None
    for names, body in re.findall(r'([^\n]+?)->HudPalette\(([^\n]+)\)', block):
        colors = re.findall(r'Color\(0x([0-9A-Fa-f]{8})\)', body)
        if len(colors) != 4: raise ValueError("Review changed Android HUD palette format")
        value = dict(zip(("panelHex", "foregroundHex", "accentHex", "mutedHex"), (color[2:] for color in colors)))
        value["panelOpacity"] = int(colors[0][:2], 16) / 255
        if names.strip() == "else": fallback = value
        for name in re.findall(r'World\.(\w+)', names): mapping[name] = value
    if fallback is None: raise ValueError("Missing Android HUD palette fallback")
    for world in worlds: world["hudPalette"] = mapping.get(world["enum"], fallback)
