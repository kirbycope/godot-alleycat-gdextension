#!/usr/bin/env python3
"""Export Alley Cat's sprites out of CAT.EXE as PNGs.

The game has no names or table for its artwork: a sprite is wherever a blitter was pointed. So the list of
what to export comes from the game itself, recorded while it runs - see `reports_sprites` on the AlleyCat
node, which reports the address, size and shape of everything drawn. Run the demo with that on, save the
catalogue, and this turns each entry into a picture.

    python tools/export_sprites.py <catalogue.json> [--out <dir>]

The catalogue is a list of {"source", "width", "height", "times", "masked"}, where source is the address the
game copied from while it was running. The image was loaded at 0x10000 and the file has a 512 byte header,
so the bytes are at (source - 0x10000) + 512 in CAT.EXE.

CGA mode 4 packs four pixels to a byte, two bits each, most significant first, and the game uses palette 1
at high intensity: black, cyan, magenta and white. All four are written out opaque, black included: the game
draws its black sprites by ANDing a shape into the background, so index 0 is the sprite rather than a hole.

A row is `width / 8` words and rows follow each other, which is how the blitters walk their source; the
screen's own two-bank interleave is a property of where the pixels go, not of the artwork itself.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

LOAD_ADDRESS = 0x10000
HEADER_BYTES = 512
# Black, light cyan, light magenta, white - all four opaque, index 0 included.
#
# Index 0 is not "nothing". Alley Cat draws its black sprites by ANDing a shape into the background, so the
# zeros are the sprite: the cat is black, and black is index 0. Writing that transparent renders every black
# sprite in the game as an empty image, which is exactly what happened the first time - the cat came out
# blank and the dog, which is magenta and white, got mistaken for it.
PALETTE = [(0, 0, 0, 255), (85, 255, 255, 255), (255, 85, 255, 255), (255, 255, 255, 255)]

# Artwork the game keeps in a table rather than reaching for one sprite at a time, listed here so it can be
# exported without having to make the game draw it.
#
# The recorded catalogue only ever holds what was drawn while it was being recorded, which was one session on
# the first screen: 93 addresses covering 22% of the artwork block. Everything on a screen nobody reached is
# missing from it, and so is every glyph that did not happen to get printed. A table is the way round that,
# because the whole run can be read out of the file whether the game ever drew it or not.
#
# Each entry is (start address, width, height, stride between entries, how many, what to call them). The
# stride is given rather than worked out, because artwork packed at one size is not always packed tightly.
TABLES = [
    # The font, found from sub_09969: it reads a digit, shifts it left by four to index this table, and blits
    # eight rows. Ten digits and then the letters the game actually prints - it carries no alphabet it has no
    # use for, which is why "I don't see all the letters" is the right observation and the answer is that
    # they were never in there. 0x129C0 onwards is not glyphs; the table is 24 entries.
    (0x12820, 8, 8, 16, 24, "Font"),
]

# Artwork named outright by a blitter call: `mov si, <address>` then `mov cx, <size>` then call. Taken from
# every such call site in the disassembly, where CL is words across (eight pixels to a word) and CH is rows.
# Sizes are given here the way the code gives them, as that packed CX, so they can be checked against it.
# Addresses are the game's own, which are offsets into its data segment; DATA_SEGMENT turns one into the
# physical address everything else here speaks in. Getting that wrong is easy and silent - the bytes still
# decode, they are just the wrong bytes - so it is written once rather than at each entry.
DATA_SEGMENT = 0x10100
DIRECT = [
    (0x064E, 0x0503), (0x000E, 0x1205), (0x000E, 0x0806), (0x000E, 0x1020),
    (0x1E50, 0x0802), (0x04D7, 0x1002), (0x2680, 0x1005), (0x296C, 0x0501),
    (0x2976, 0x0C05), (0x29EE, 0x0804), (0x2A2E, 0x0B04), (0x3350, 0x1205),
    (0x3404, 0x0202), (0x6152, 0x1D0B), (0x63D0, 0x160E), (0x6638, 0x0C03),
    (0x6680, 0x080E), (0x6760, 0x0B0C), (0x6868, 0x0804),
]

# Tables of artwork addresses, read out of the file. Each is (address of the table, how many entries, the
# size the call site blits them at). The count is where the next thing the code refers to begins - a table
# ends where the next named address starts, which is the only boundary the file gives.
POINTER_TABLES = [
    (0x0F92, 8, 0x0602), (0x0FA2, 4, 0x0602), (0x1F59, 3, 0x0802),
    (0x2AD1, 4, 0x0801), (0x6A8F, 2, 0x0C0A),
]

# The one table that carries its own sizes: addresses at the first, the packed CX for each at the second.
SIZED_TABLE = (0x584C, 0x5858, 6)


def size_of(cx):
    """Width and height out of the packed CX the blitters take: CL words across, eight pixels a word."""
    return (cx & 0xFF) * 8, cx >> 8


def table_entries(exe=None):
    """Everything the code names statically, in the same shape as a recorded catalogue entry.

    The evenly strided tables, the sprites a call site names outright, and the tables of addresses the code
    indexes into. None of these carry a draw count: they were read out of the file rather than watched being
    drawn, which is the whole point - a recording only ever holds what the session it was recorded in
    happened to reach.
    """
    out = []
    for start, width, height, stride, count, group in TABLES:
        for i in range(count):
            out.append({"source": start + i * stride, "width": width, "height": height,
                        "times": 0, "masked": 0, "group": group, "index": i})
    for offset, cx in DIRECT:
        width, height = size_of(cx)
        out.append({"source": DATA_SEGMENT + offset, "width": width, "height": height,
                    "times": 0, "masked": 0, "group": "", "index": -1})
    if exe is None:
        return out

    def word(offset):
        at = DATA_SEGMENT + offset - LOAD_ADDRESS + HEADER_BYTES
        return exe[at] | (exe[at + 1] << 8)

    for base, count, cx in POINTER_TABLES:
        width, height = size_of(cx)
        for i in range(count):
            out.append({"source": DATA_SEGMENT + word(base + i * 2), "width": width, "height": height,
                        "times": 0, "masked": 0, "group": "", "index": -1})
    addresses, sizes, count = SIZED_TABLE
    for i in range(count):
        width, height = size_of(word(sizes + i * 2))
        out.append({"source": DATA_SEGMENT + word(addresses + i * 2), "width": width, "height": height,
                    "times": 0, "masked": 0, "group": "", "index": -1})
    return out


def decode(data: bytes, width: int, height: int):
    """The bytes of one sprite as a list of RGBA rows, or None where they run past the end of the file."""
    per_row = width // 4
    if per_row <= 0 or height <= 0 or len(data) < per_row * height:
        return None
    rows = []
    for y in range(height):
        row = []
        for byte in data[y * per_row:(y + 1) * per_row]:
            for shift in (6, 4, 2, 0):
                row.append(PALETTE[(byte >> shift) & 3])
        rows.append(row)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Export Alley Cat's sprites out of CAT.EXE")
    parser.add_argument("catalogue", help="JSON recorded from the running game")
    parser.add_argument("--exe", default="addons/godot_alleycat_gdextension/assets/CAT.EXE")
    parser.add_argument("--out", default="addons/godot_alleycat_gdextension/assets/artwork/original")
    parser.add_argument("--fresh", action="store_true",
                        help="start the catalogue over rather than adding to what is already there")
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow is needed to write the PNGs: python -m pip install pillow")

    exe = pathlib.Path(args.exe).read_bytes()
    entries = json.loads(pathlib.Path(args.catalogue).read_text(encoding="utf-8"))
    # Every sweep adds to what is already known rather than replacing it. One session only ever reaches the
    # screens that session reached, so the catalogue is something that grows: run the sweep somewhere new and
    # the sprites drawn there join the ones already found.
    out_dir = pathlib.Path(args.out)
    before = out_dir / "index.json"
    if before.exists() and not args.fresh:
        already = json.loads(before.read_text(encoding="utf-8"))
        have = {(e["source"], e["width"], e["height"]) for e in entries}
        for entry in already:
            if (entry["source"], entry["width"], entry["height"]) not in have:
                entries.append(entry)
    # The tables go in alongside whatever was recorded, and where the two meet they are merged rather than
    # one dropped: the recorded entry has the draw counts and the table entry knows what family the sprite is
    # in and where it sits in it, and both are worth keeping.
    recorded = {(e["source"], e["width"], e["height"]): e for e in entries}
    for entry in table_entries(exe):
        key = (entry["source"], entry["width"], entry["height"])
        if key in recorded:
            recorded[key]["group"] = entry["group"]
            recorded[key]["index"] = entry["index"]
        else:
            entries.append(entry)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    written, skipped = 0, 0
    index = []
    for entry in sorted(entries, key=lambda e: (e["source"], e["width"], e["height"])):
        source, width, height = entry["source"], entry["width"], entry["height"]
        at = source - LOAD_ADDRESS + HEADER_BYTES
        if at < 0 or at >= len(exe):
            skipped += 1
            continue
        rows = decode(exe[at:], width, height)
        if rows is None:
            skipped += 1
            continue
        image = Image.new("RGBA", (width, height))
        image.putdata([pixel for row in rows for pixel in row])
        # Named by where it lives, because that is the only name the game gives it.
        name = "sprite_%05X_%dx%d.png" % (source, width, height)
        image.save(out / name)
        index.append({"source": source, "width": width, "height": height,
                      "file": name, "times": entry.get("times", 0), "masked": entry.get("masked", 0),
                      "group": entry.get("group", ""), "index": entry.get("index", -1)})
        written += 1

    (out / "index.json").write_text(json.dumps(index, indent=2), encoding="utf-8")
    print("wrote %d sprites to %s" % (written, out))
    if skipped:
        print("skipped %d whose bytes fall outside the file" % skipped)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
