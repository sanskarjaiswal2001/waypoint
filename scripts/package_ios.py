#!/usr/bin/env python3
"""Package and validate a device build as an unsigned IPA for external signing."""

import hashlib
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile


app = Path(sys.argv[1]).resolve()
destination = Path(sys.argv[2]).resolve()
if not app.is_dir() or app.suffix != ".app":
    raise SystemExit("Expected a built .app directory")
with (app / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
    raise SystemExit("An IPA must contain an iPhoneOS build, not a simulator build")
binary = app / info["CFBundleExecutable"]
architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).strip().split()
if architectures != ["arm64"]:
    raise SystemExit("Expected an arm64 device executable")
build_metadata = subprocess.check_output(["vtool", "-show-build", str(binary)], text=True)
if re.findall(r"platform\s+(\S+)", build_metadata) != ["IOS"]:
    raise SystemExit("Expected a Mach-O executable built for iOS devices")
if any(app.rglob("*.appex")):
    raise SystemExit("Unexpected app extensions in the sideload build")
destination.mkdir(parents=True, exist_ok=True)
staging = destination / "staging"
if staging.exists():
    shutil.rmtree(staging)
staged_app = staging / "Payload/Waypoint.app"
shutil.copytree(app, staged_app, symlinks=True)
for signature in staged_app.rglob("_CodeSignature"):
    shutil.rmtree(signature)
for profile in staged_app.rglob("embedded.mobileprovision"):
    profile.unlink()
ipa = destination / "Waypoint-iOS-unsigned.ipa"
with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(staging.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(staging))
with zipfile.ZipFile(ipa) as archive:
    if archive.testzip() is not None or "Payload/Waypoint.app/Info.plist" not in archive.namelist():
        raise SystemExit("IPA integrity check failed")
(destination / "SHA256SUMS-iOS").write_text(hashlib.sha256(ipa.read_bytes()).hexdigest() + "  " + ipa.name + "\n")
shutil.rmtree(staging)
print(f"Packaged unsigned arm64 IPA: {ipa.name} ({ipa.stat().st_size // 1024 // 1024} MiB)")
