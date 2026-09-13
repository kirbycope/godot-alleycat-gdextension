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
    EXAMPLES[_source] = "cat_walk_left_%02d.png" % _frame
for _frame, _source in enumerate(CAT_WALK_RIGHT, start=1):
    EXAMPLES[_source] = "cat_walk_right_%02d.png" % _frame

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

# Best guesses for the rest, from a sweep that recorded which room each sprite was drawn in and where, the
# room routines in the disassembly, and a look at the picture. A name somebody types in the panel wins over
# any of these, and a row not listed here keeps its address as its name. Where the guess is a guess, the
# name says so with a question mark rather than pretending.
GUESSES = {
    # The cat, beyond walking and standing.
    0x10B7C: ("Cat Jump Up 2", "Cat"),
    0x10BCA: ("Cat Leap 1 of 2", "Cat"), 0x10C12: ("Cat Leap 2 of 2", "Cat"),
    0x10C5A: ("Cat Leap Land 1 of 2", "Cat"), 0x10C96: ("Cat Leap Land 2 of 2", "Cat"),
    0x10ADA: ("Cat Fall", "Cat"),
    0x10974: ("Cat Rear Up 1 of 2", "Cat"), 0x109C8: ("Cat Rear Up 2 of 2", "Cat"),
    # In the fishbowl.
    0x107D0: ("Cat Swim Left 1 of 3", "Fishbowl"), 0x10818: ("Cat Swim Left 2 of 3", "Fishbowl"),
    0x10866: ("Cat Swim Left 3 of 3", "Fishbowl"),
    0x108A2: ("Cat Swim Right 1 of 3", "Fishbowl"), 0x108EA: ("Cat Swim Right 2 of 3", "Fishbowl"),
    0x10938: ("Cat Swim Right 3 of 3", "Fishbowl"),
    0x10A16: ("Cat Swim Sink?", "Fishbowl"), 0x10A4E: ("Cat Swim Tread?", "Fishbowl"), 0x10A82: ("Cat Swim Small", "Fishbowl"),
    0x12120: ("Fish Small 1 of 4", "Fishbowl"), 0x12128: ("Fish Small 2 of 4", "Fishbowl"),
    0x12130: ("Fish Small 3 of 4", "Fishbowl"), 0x12138: ("Fish Small 4 of 4", "Fishbowl"),
    0x13400: ("Fish 1 of 4", "Fishbowl"), 0x1340C: ("Fish 2 of 4", "Fishbowl"),
    0x13418: ("Fish 3 of 4", "Fishbowl"), 0x13424: ("Fish 4 of 4", "Fishbowl"),
    0x13430: ("Water Ripple 1 of 4", "Fishbowl"), 0x13438: ("Water Ripple 2 of 4", "Fishbowl"),
    0x13440: ("Water Ripple 3 of 4", "Fishbowl"), 0x13448: ("Water Ripple 4 of 4", "Fishbowl"),
    0x13450: ("ZAP", "Fishbowl"), 0x1074E: ("GLUB", "Fishbowl"),
    0x13630: ("Fishbowl on Table 1 of 4", "Fishbowl"), 0x13658: ("Fishbowl on Table 2 of 4", "Fishbowl"),
    0x13680: ("Fishbowl on Table 3 of 4", "Fishbowl"), 0x136A8: ("Fishbowl on Table 4 of 4", "Fishbowl"),
    # The bookcase.
    0x139BC: ("Spider 1 of 3", "Bookcase"), 0x13A10: ("Spider 2 of 3", "Bookcase"), 0x13A6F: ("Spider 3 of 3", "Bookcase"),
    0x138C0: ("Bye!!", "Bookcase"),
    0x13830: ("Shelf Item 1 of 7", "Bookcase"), 0x13840: ("Shelf Item 2 of 7", "Bookcase"),
    0x13850: ("Shelf Item 3 of 7", "Bookcase"), 0x13860: ("Shelf Item 4 of 7", "Bookcase"),
    0x13870: ("Shelf Item 5 of 7", "Bookcase"), 0x13880: ("Shelf Item 6 of 7", "Bookcase"),
    0x13890: ("Shelf Item 7 of 7", "Bookcase"),
    # The cheese.
    0x13E20: ("Cheese Mouse Left", "Cheese"), 0x13E50: ("Cheese Mouse Right", "Cheese"),
    0x13E80: ("Cheese Mouse Peek 1 of 2", "Cheese"), 0x13EB0: ("Cheese Mouse Peek 2 of 2", "Cheese"),
    0x13BF8: ("Cheese Bit 1 of 2", "Cheese"), 0x13C02: ("Cheese Bit 2 of 2", "Cheese"),
    0x13DAA: ("Cheese Edge", "Cheese"),
    # The birdcage and the dogs.
    0x140BE: ("Birdcage 1 of 2", "Birdcage"), 0x1411E: ("Birdcage 2 of 2", "Birdcage"),
    0x1182D: ("Bird Flying?", "Birdcage"),
    0x1439C: ("Dog Asleep 1 of 2", "Dog"), 0x1441E: ("Dog Asleep 2 of 2", "Dog"), 0x1431C: ("Dog Bowl", "Dog"),
    0x115D8: ("Dog Run 3 of 5", "Dog"), 0x11650: ("Dog Run 4 of 5", "Dog"),
    0x11779: ("BONK!", "Fight"), 0x11E70: ("SQUEAK!", "Fight"), 0x16F58: ("Fight Swearing", "Fight"),
    # The rooms in general.
    0x120A0: ("Portrait Man", "Room"), 0x120E0: ("Portrait Woman", "Room"),
    0x133B8: ("Broom Dust 1 of 3", "Room"), 0x133C2: ("Broom Dust 2 of 3", "Room"), 0x133CC: ("Broom Dust 3 of 3", "Room"),
    # The hearts.
    0x12BF0: ("Girl Cat", "Hearts"), 0x12EE0: ("Heart", "Hearts"), 0x12F00: ("Heart Cracked?", "Hearts"),
    0x17030: ("Hearts Arrow 1 of 12", "Hearts"), 0x17050: ("Hearts Arrow 2 of 12", "Hearts"),
    0x17070: ("Hearts Arrow 3 of 12", "Hearts"), 0x17090: ("Hearts Arrow 4 of 12", "Hearts"),
    0x170B0: ("Hearts Arrow 5 of 12", "Hearts"), 0x170D0: ("Hearts Arrow 6 of 12", "Hearts"),
    0x170F0: ("Hearts Arrow 7 of 12", "Hearts"), 0x17110: ("Hearts Arrow 8 of 12", "Hearts"),
    0x17130: ("Hearts Arrow 9 of 12", "Hearts"), 0x17150: ("Hearts Arrow 10 of 12", "Hearts"),
    0x17170: ("Hearts Arrow 11 of 12", "Hearts"), 0x17190: ("Hearts Arrow 12 of 12", "Hearts"),
    # The alley and the title.
    0x11ED0: ("Points 50", "Score"), 0x11EF0: ("Points 70", "Score"), 0x11F10: ("Points 90", "Score"),
    0x16F10: ("Title Cat Face", "Title"), 0x169A8: ("IBM Corp.", "Title"),
    0x16252: ("IBM Presents", "Title"), 0x164D0: ("Alley Cat TM", "Title"), 0x16738: ("By", "Title"),
    0x16780: ("Bill Williams", "Title"), 0x16860: ("(c) Copyright", "Title"), 0x16968: ("1984", "Title"),
    0x16A98: ("SynSoft TM", "Title"),
    0x11380: ("Fight Cloud 1 of 3", "Fight"), 0x113F8: ("Fight Cloud 2 of 3", "Fight"), 0x11470: ("Fight Cloud 3 of 3", "Fight"),
    0x14202: ("White Line 8x1", "Cheese"),
    0x12780: ("Window", "Window"),
    0x12A04: ("Fence Piece 1 of 9", "Fence"), 0x12A14: ("Fence Piece 2 of 9", "Fence"),
    0x12A24: ("Fence Piece 3 of 9", "Fence"), 0x12A34: ("Fence Piece 4 of 9", "Fence"),
    0x12A44: ("Fence Piece 5 of 9", "Fence"), 0x12A4E: ("Fence Piece 6 of 9", "Fence"),
    0x12A58: ("Fence Piece 7 of 9", "Fence"), 0x12A62: ("Fence Piece 8 of 9", "Fence"),
    0x12A6C: ("Fence Piece 9 of 9", "Fence"),
}
for _source, (_name, _group) in GUESSES.items():
    KNOWN.setdefault(_source, _name)
    GROUPS.setdefault(_source, _group)

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
    # The worked example, plus every replacement anybody has since dropped on a sprite themselves. Only
    # from rows that are still here: a row on its way out - a clipped column mistaken for a sprite, say -
    # sits at the same address as the real one, and its texture must not land on the survivor.
    surviving = {"S_%05X_%dx%d" % (e["source"], e["width"], e["height"]) for e in index}
    replacements = dict(EXAMPLES)
    for ident, entry in kept.items():
        if "texture" in entry and ident in surviving:
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
        # Which routine draws it says which colour the game leaves see-through, and so what a replacement's
        # transparency should follow. The exported picture already has that as alpha; this says why.
        drawn = {"masked": "ANDed into the background, so white is see-through and black is ink",
                 "keyed": "laid over the background with black see-through",
                 "plain": "copied whole, nothing see-through"}.get(entry.get("kind", ""), "")
        note = entry.get("note") or "%dx%d, drawn %d times%s" % (
            entry["width"], entry["height"], entry["times"], ("; " + drawn) if drawn else "")
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
