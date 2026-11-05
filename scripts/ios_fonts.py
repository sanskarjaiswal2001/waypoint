"""Normalize invalid font names in staged copies; retain glyphs and licence records."""
import struct
from pathlib import Path


def checksum(data):
    data = bytes(data)
    data += b"\0" * (-len(data) % 4)
    return sum(struct.unpack(f">{len(data) // 4}I", data)) & 0xFFFFFFFF


def normalize_stratum(path):
    path = Path(path)
    original = path.read_bytes()
    count = struct.unpack_from(">H", original, 4)[0]
    tables = {}
    for index in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", original, 12 + index * 16)
        tables[tag] = original[offset:offset + length]
    names = tables[b"name"]
    format_, records, start = struct.unpack_from(">HHH", names)
    if format_ != 0: raise ValueError("Review changed Stratum name table format")
    entries = []
    invalid = False
    for index in range(records):
        platform, encoding, language, key, size, offset = struct.unpack_from(">HHHHHH", names, 6 + index * 12)
        value = names[start + offset:start + offset + size]
        codec = "utf-16-be" if platform in (0, 3) else "mac-roman"
        if key == 6:
            text = value.decode(codec)
            invalid |= not text or any(ord(c) < 33 or ord(c) > 126 or c in "[](){}<>/%" for c in text)
        entries.append((platform, encoding, language, key, value, codec))
    if not invalid: return False
    style = "Bold" if "bold" in path.stem else "Regular"
    replacements = {1: "Waypoint Stratum 2", 2: style, 4: "Waypoint Stratum 2 " + style, 6: "WaypointStratum2-" + style}
    directory, strings = bytearray(), bytearray()
    for platform, encoding, language, key, value, codec in entries:
        value = replacements[key].encode(codec) if key in replacements else value
        directory += struct.pack(">HHHHHH", platform, encoding, language, key, len(value), len(strings))
        strings += value
    tables[b"name"] = struct.pack(">HHH", 0, records, 6 + records * 12) + directory + strings
    head = bytearray(tables[b"head"]); head[8:12] = b"\0" * 4; tables[b"head"] = head
    output = bytearray(original[:12] + b"\0" * (count * 16))
    offsets = {}
    for index, (tag, data) in enumerate(tables.items()):
        offsets[tag] = len(output)
        struct.pack_into(">4sIII", output, 12 + index * 16, tag, checksum(data), len(output), len(data))
        output += data
        output += b"\0" * (-len(output) % 4)
    struct.pack_into(">I", output, offsets[b"head"] + 8, (0xB1B0AFBA - checksum(output)) & 0xFFFFFFFF)
    if checksum(output) != 0xB1B0AFBA: raise ValueError("Invalid staged font checksum")
    path.write_bytes(output)
    return True
