#!/usr/bin/env python3
"""Build resources/artwork.tres from the exported sprites, so every sprite the game draws has a slot.

    python tools/build_artwork_resource.py

Each entry carries the game's own artwork in `original`, which is what says which sprite it is: the game has
no names for its artwork, only the address it copies from, and an address on its own tells you nothing.
`texture` is the override and is left empty, so by default nothing is replaced and the game looks exactly as
it shipped. Dropping a texture into one slot in the inspector replaces that sprite and nothing else.

EXAMPLES is the one that ships filled in, as a worked example.
"""

from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path("addons/godot_alleycat_gdextension")
# The cat as it walks: three frames at 32x15, which is what the exported artwork shows. Replacing one of
# them only puts the cat there for the third of the time that frame is up, which reads as a flicker - a
# replacement has to cover a whole animation, not a picture.
# The player's cat: black, 24x11, and five frames of walk. Found by holding left and then right and seeing
# which artwork moved with the player - and then by looking at it, because two families move with the player
# and the other one is the dog chasing the cat. The cat is the black one.
EXAMPLES = {
    0x10E5E: "cat_1.png",
    0x10EA0: "cat_2.png",
    0x10EE2: "cat_3.png",
    0x10F24: "cat_4.png",
    0x10FA8: "cat_5.png",
}

TEXTURE = '[ext_resource type="Texture2D" path="res://addons/godot_alleycat_gdextension/assets/artwork/%s" id="%s"]'


def main() -> int:
    index = json.loads((ROOT / "assets/artwork/original/index.json").read_text(encoding="utf-8"))
    index.sort(key=lambda e: (-e["times"], e["source"]))

    ext = [
        '[ext_resource type="Script" path="res://addons/godot_alleycat_gdextension/scripts/alley_cat_artwork.gd" id="1_artwork"]',
        '[ext_resource type="Script" path="res://addons/godot_alleycat_gdextension/scripts/alley_cat_sprite.gd" id="2_sprite"]',
    ]
    next_id = 3
    overrides = {}
    for source, name in sorted(EXAMPLES.items()):
        overrides[source] = "%d_over" % next_id
        ext.append(TEXTURE % (name, overrides[source]))
        next_id += 1

    subs, order = [], []
    for entry in index:
        original_id = "%d_o" % next_id
        next_id += 1
        ext.append(TEXTURE % ("original/" + entry["file"], original_id))
        name = "S_%05X_%dx%d" % (entry["source"], entry["width"], entry["height"])
        mask = entry["masked"] >= max(1, entry["times"]) * 0.5
        note = "%dx%d, drawn %d times%s" % (
            entry["width"], entry["height"], entry["times"],
            ", a mask rather than a picture" if mask else "")
        lines = ['[sub_resource type="Resource" id="%s"]' % name,
                 'script = ExtResource("2_sprite")',
                 "source = %d" % entry["source"]]
        if entry["source"] in overrides:
            lines.append('texture = ExtResource("%s")' % overrides[entry["source"]])
        lines += ['original = ExtResource("%s")' % original_id,
                  "draws = %d" % entry["times"],
                  "masked_draws = %d" % entry["masked"],
                  'note = "%s"' % note]
        subs.append("\n".join(lines))
        order.append('SubResource("%s")' % name)

    header = '[gd_resource type="Resource" script_class="AlleyCatArtwork" load_steps=%d format=3]' % (
        len(ext) + len(subs) + 1)
    resource = '[resource]\nscript = ExtResource("1_artwork")\nsprites = Array[ExtResource("2_sprite")]([%s])' % (
        ", ".join(order))
    body = "\n\n".join([header, "\n".join(ext), "\n\n".join(subs), resource]) + "\n"
    (ROOT / "resources/artwork.tres").write_text(body, encoding="utf-8")
    print("wrote artwork.tres with %d sprites, %d filled in as examples" % (len(index), len(EXAMPLES)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
