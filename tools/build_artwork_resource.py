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
import re

ROOT = pathlib.Path("addons/godot_alleycat_gdextension")
# The player's cat, the whole of it: a six frame walk each way, found by holding left and then right in a
# real game and reading back what the game reported drawing. Covering one direction is what made the
# replacement appear only while the cat walked left; covering one frame of a direction makes it flicker.
#
# The art is drawn facing right, so the left-hand walk is the mirror of it. Getting that backwards is easy
# and looks like the cat moonwalking.
#
# Not covered, and left as the game drew it: the cat standing still. The game stops drawing a walk frame
# and starts drawing the mask at 0x106FA in its place, which is a plain black box shared with other things
# on the screen, so a replacement hung on it would follow them about too.
CAT_WALK_LEFT = [0x10E5E, 0x10EA0, 0x10EE2, 0x10F24, 0x10F66, 0x10FA8]
CAT_WALK_RIGHT = [0x10CD2, 0x10D14, 0x10D56, 0x10D98, 0x10DDA, 0x10E1C]
EXAMPLES = {}
for _frame, _source in enumerate(CAT_WALK_LEFT, start=1):
    EXAMPLES[_source] = "cat_walk_left_%d.png" % _frame
for _frame, _source in enumerate(CAT_WALK_RIGHT, start=1):
    EXAMPLES[_source] = "cat_walk_right_%d.png" % _frame

# Names for the ones that are known, so the list can be read down rather than clicked through. Anything not
# named here gets its address, size and draw count instead, which is enough to find it on a contact sheet.
# Add to this as sprites are identified: it is the one place a name has to be written to survive a rebuild,
# because rebuilding is what turns a fresh catalogue into a resource and it does not read the old one.
KNOWN = {}
# What each one belongs to. Most of the game's artwork comes in families - a thing that walks is six frames
# each way - so the family is the useful unit when replacing artwork, and the browser filters the sheet by it.
GROUPS = {}
for _frame, _source in enumerate(CAT_WALK_LEFT, start=1):
    KNOWN[_source] = "Cat walk left %d of %d" % (_frame, len(CAT_WALK_LEFT))
    GROUPS[_source] = "Cat"
for _frame, _source in enumerate(CAT_WALK_RIGHT, start=1):
    KNOWN[_source] = "Cat walk right %d of %d" % (_frame, len(CAT_WALK_RIGHT))
    GROUPS[_source] = "Cat"

TEXTURE = '[ext_resource type="Texture2D" path="res://addons/godot_alleycat_gdextension/assets/artwork/%s" id="%s"]'


def already_written(tres: pathlib.Path) -> dict:
    """What a person has already typed into the catalogue, keyed by the id of the entry they typed it on.

    This script builds `artwork.tres` from nothing every time it runs, and the browser writes names, groups
    and replacement textures into that same file. Without reading the old one first, a rebuild throws away
    every name anybody has worked out - which is not a theoretical risk, it happened twice.

    The key is the sub-resource id this script gives each entry, `S_<address>_<width>x<height>`. Godot keeps
    it across a save, it says both the things that identify an entry, and it needs no cross-referencing. The
    address alone will not do: the game blits some artwork at more than one size and each size is its own
    row, so a name set on one row would land on its siblings as well.

    Only what a person could have set is taken back - a name that is not the generated `0x...` form, a group,
    and a replacement texture. The facts are rebuilt from the catalogue, because those are not anybody's
    opinion.
    """
    if not tres.exists():
        return {}
    text = tres.read_text(encoding="utf-8")
    paths = {ident: path for path, ident in
             re.findall(r'\[ext_resource type="Texture2D"[^\]]*? path="([^"]+)" id="([^"]+)"\]', text)}
    kept = {}
    for block in text.split("[sub_resource")[1:]:
        ident = re.match(r'[^\]]*id="([^"]+)"\]', block)
        if ident is None:
            continue
        entry = {}
        label = re.search(r'^label = "(.*)"$', block, re.M)
        if label is not None and label.group(1) and not label.group(1).startswith("0x"):
            entry["label"] = label.group(1)
        group = re.search(r'^group = "(.*)"$', block, re.M)
        if group is not None and group.group(1):
            entry["group"] = group.group(1)
        texture = re.search(r'^texture = ExtResource\("([^"]+)"\)$', block, re.M)
        if texture is not None and texture.group(1) in paths:
            entry["texture"] = paths[texture.group(1)].rsplit("/artwork/", 1)[-1]
        if entry:
            kept[ident.group(1)] = entry
    return kept


def is_blank(path: pathlib.Path) -> bool:
    """Whether an exported sprite is one flat colour, which is nothing anybody can replace.

    Some of what the game blits is not a picture: a run of identical bytes used to clear a strip, or an
    address the report gave a size that does not belong to it. Either way it decodes to a rectangle of one
    colour, and a catalogue of over a hundred entries is hard enough to read without rows that show a black
    square and mean nothing. Pillow is already what `export_sprites.py` writes these with.
    """
    from PIL import Image

    with Image.open(path) as image:
        colours = image.convert("RGBA").getcolors(maxcolors=4)
    # getcolors returns None once there are more than maxcolors of them, which is plainly not one flat colour.
    return colours is not None and len(colours) == 1

def main() -> int:
    kept = already_written(ROOT / "resources/artwork.tres")
    index = json.loads((ROOT / "assets/artwork/original/index.json").read_text(encoding="utf-8"))
    for entry in index:
        entry.setdefault("file", entry.get("file"))
    # Artwork that is not in CAT.EXE. The drawn letters are written into the machine's memory rather than
    # found in the file, so they cannot come out of the exporter with the rest; they are catalogued the same
    # way regardless, because from the browser's point of view a sprite is a picture at an address.
    added = ROOT / "assets/artwork/added/index.json"
    if added.exists():
        index += json.loads(added.read_text(encoding="utf-8"))
    # One row per address and size. The catalogue is built up from several places - a recording, the tables
    # read out of the file, the letters drawn for it - and two of them naming the same sprite would put two
    # rows on the sheet with the same name and no way to tell them apart.
    seen = set()
    unique = []
    for entry in index:
        key = (entry["source"], entry["width"], entry["height"])
        if key not in seen:
            seen.add(key)
            unique.append(entry)
    index = unique
    blank = [e for e in index
             if is_blank(ROOT / "assets/artwork" / (e["file"] if "/" in e["file"] else "original/" + e["file"]))]
    index = [e for e in index if e not in blank]
    index.sort(key=lambda e: (-e["times"], e["source"]))
    sizes = {}
    for entry in index:
        sizes[entry["source"]] = sizes.get(entry["source"], 0) + 1

    ext = [
        '[ext_resource type="Script" path="res://addons/godot_alleycat_gdextension/scripts/alley_cat_artwork.gd" id="1_artwork"]',
        '[ext_resource type="Script" path="res://addons/godot_alleycat_gdextension/scripts/alley_cat_sprite.gd" id="2_sprite"]',
    ]
    next_id = 3
    overrides = {}
    # The worked example, plus every replacement anybody has since dropped on a sprite themselves.
    replacements = dict(EXAMPLES)
    for ident, entry in kept.items():
        if "texture" in entry:
            found = re.match(r"S_([0-9A-F]+)_", ident)
            if found is not None:
                replacements[int(found.group(1), 16)] = entry["texture"]
    for source, name in sorted(replacements.items()):
        overrides[source] = "%d_over" % next_id
        ext.append(TEXTURE % (name, overrides[source]))
        next_id += 1

    subs, order = [], []
    for entry in index:
        original_id = "%d_o" % next_id
        next_id += 1
        # An entry says where its own picture is: the exporter writes "original/..." and anything drawn
        # elsewhere brings its own folder with it.
        where: str = entry["file"] if "/" in entry["file"] else "original/" + entry["file"]
        ext.append(TEXTURE % (where, original_id))
        name = "S_%05X_%dx%d" % (entry["source"], entry["width"], entry["height"])
        mask = entry["masked"] >= max(1, entry["times"]) * 0.5
        note = entry.get("note") or "%dx%d, drawn %d times%s" % (
            entry["width"], entry["height"], entry["times"],
            ", a mask rather than a picture" if mask else "")
        # What a person typed wins over anything this script would have called it, and is used exactly as
        # they left it. Adding anything to it would be added again on the next run, and the run after that.
        mine = kept.get(name, {})
        label = mine.get("label")
        if label is None:
            # An entry that arrived with a name of its own keeps it. The drawn letters know what they are,
            # because they were drawn to be a particular letter rather than found and puzzled over.
            label = entry.get("label") or KNOWN.get(entry["source"])
            # Anything the exporter took out of a table already knows what family it is in and where it sits
            # in it, so it names itself: the font's first ten entries are the digits, in order.
            if label is None and entry.get("group") == "Font":
                place = int(entry.get("index", -1))
                label = "Digit %d" % place if 0 <= place <= 9 else "Font glyph %d" % place
            if label is None:
                label = "0x%05X  %dx%d  drawn %d" % (entry["source"], entry["width"], entry["height"],
                                                     entry["times"])
            elif sizes[entry["source"]] > 1:
                # The game blits some artwork at more than one size and each size is its own entry, so a name
                # on its own would put the same words on two rows with no way to tell them apart.
                label += "  (%dx%d)" % (entry["width"], entry["height"])
        lines = ['[sub_resource type="Resource" id="%s"]' % name,
                 'script = ExtResource("2_sprite")',
                 'resource_name = "%s"' % label,
                 'label = "%s"' % label,
                 'group = "%s"' % (mine.get("group")
                                   or GROUPS.get(entry["source"], entry.get("group", ""))),
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
    print("wrote artwork.tres with %d sprites, %d replaced, %d blanks left out; kept %d names and groups "
          "already in the file" % (len(index), len(replacements), len(blank), len(kept)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
