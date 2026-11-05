import tempfile
import unittest
from pathlib import Path
from ios_catalogue import read_worlds, validate_worlds, typefaces


class CatalogueTests(unittest.TestCase):
    root = Path(__file__).resolve().parents[1]

    def test_current_catalogue_has_assets_and_explicit_native_huds(self):
        worlds = read_worlds((self.root / "app/src/main/java/com/waypoint/app/World.kt").read_text())
        validate_worlds(self.root, worlds)
        typefaces(self.root, worlds)
        self.assertTrue(all(w.get("titleTypeface") and w.get("readingTypeface") for w in worlds))
        self.assertTrue({"division", "nier", "stalker"}.issubset({w["id"] for w in worlds}))

    def test_new_world_is_parsed_without_changing_a_count(self):
        source = 'EXAMPLE("Example","Example world",R.string.example,"example",Color(0xFFAABBCC),"#DDEEFF",Color(0xFF112233)),\n'
        self.assertEqual(["example"], [w["id"] for w in read_worlds(source)])
        self.assertEqual(2, len(read_worlds(source + source.replace("EXAMPLE", "ANOTHER").replace('"example"', '"another"'))))

    def test_unknown_enum_format_and_duplicate_ids_fail(self):
        source = 'EXAMPLE("Example","Example world",R.string.example,"example",Color(0xFFAABBCC),"#DDEEFF",Color(0xFF112233)),\n'
        with self.assertRaises(ValueError): read_worlds(source + 'ANOTHER("different constructor")\n')
        with self.assertRaises(ValueError): read_worlds(source + source.replace("EXAMPLE", "ANOTHER"))

    def test_missing_assets_and_missing_native_layout_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            chrome = root / "ios/Waypoint/AtlasChrome.swift"
            chrome.parent.mkdir(parents=True)
            chrome.write_text('private var composition: some View { switch id { default: compact } }')
            with self.assertRaisesRegex(ValueError, "missing map style"): validate_worlds(root, [{"id": "example"}])
            with self.assertRaisesRegex(ValueError, "missing native phone HUD"): validate_worlds(root, [{"id": "example"}])


if __name__ == "__main__": unittest.main()
