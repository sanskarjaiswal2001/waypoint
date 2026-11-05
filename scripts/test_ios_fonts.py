import shutil
import struct
import tempfile
import unittest
from pathlib import Path
from ios_fonts import checksum, normalize_stratum


def tables(data):
    result = {}
    for index in range(struct.unpack_from(">H", data, 4)[0]):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + index * 16)
        result[tag] = data[offset:offset + length]
    return result


def name_records(data):
    _, count, start = struct.unpack_from(">HHH", data)
    records = {}
    for index in range(count):
        platform, encoding, language, key, size, offset = struct.unpack_from(">HHHHHH", data, 6 + index * 12)
        records[platform, encoding, language, key] = data[start + offset:start + offset + size]
    return records


class FontTests(unittest.TestCase):
    def test_only_names_and_checksum_change_and_second_pass_is_stable(self):
        root = Path(__file__).resolve().parents[1]
        for name in ("stratum2_regular.ttf", "stratum2_bold.ttf"):
            source = root / "app/src/main/res/font" / name
            original = source.read_bytes()
            with tempfile.TemporaryDirectory() as directory:
                target = Path(directory) / name
                shutil.copyfile(source, target)
                self.assertTrue(normalize_stratum(target))
                fixed = target.read_bytes()
                self.assertEqual(checksum(fixed), 0xB1B0AFBA)
                before, after = tables(original), tables(fixed)
                self.assertEqual(set(before), set(after))
                for tag in before.keys() - {b"head", b"name"}: self.assertEqual(before[tag], after[tag], tag)
                self.assertEqual(before[b"head"][:8] + before[b"head"][12:], after[b"head"][:8] + after[b"head"][12:])
                old_names, new_names = name_records(before[b"name"]), name_records(after[b"name"])
                for key, value in old_names.items():
                    if key[3] not in (1, 2, 4, 6): self.assertEqual(value, new_names[key])
                self.assertFalse(normalize_stratum(target))
                self.assertEqual(target.read_bytes(), fixed)
            self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__": unittest.main()
