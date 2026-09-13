#!/usr/bin/env python3
"""Export Alley Cat's sprites out of CAT.EXE as PNGs.

The game has no names or table for its artwork: a sprite is wherever a blitter was pointed. So the list of
what to export comes from the game itself, recorded while it runs - see `reports_sprites` on the AlleyCat
node, which reports the address, size and shape of everything drawn. Run `tools/sweep.gd` against the demo,
save what it returns, and this turns each entry into a picture.

    python tools/export_sprites.py <catalogue.json> [--out <dir>]

The catalogue is a list of {"source", "width", "height", "times", "masked", "kind", "buffer"}, where source
is the address the game copied from while it was running. The image was loaded at 0x10000 and the file has
a 512 byte header, so the bytes are at (source - 0x10000) + 512 in CAT.EXE.

CGA mode 4 packs four pixels to a byte, two bits each, most significant first, and the game uses palette 1
at high intensity: black, cyan, magenta and white. Which of those is see-through depends on which routine
drew the sprite, and that is the one thing the bytes cannot say on their own:

- "masked" - sub_09F65 ANDs the sprite into the background, so white leaves the background alone and black
  is ink. The cat, the mice. Written out with white transparent.
- "keyed" - sub_09EFC lays the sprite over the background with black as the key, working the mask out from
  the pixels as it goes. The dog, the thing in the bins. Written out with black transparent.
- "plain" - sub_09FCD copies every pixel. The scenery, the title, the font. Written out opaque.

Two kinds of catalogue entry are not artwork at all and are dropped here. A *buffer* is somewhere the game
saves the background before drawing over it, and restores from afterwards: what CAT.EXE holds at that
offset is nothing. A *phantom* is a narrower entry starting inside the first row of a wider one of the same
height - that is the game clipping a sprite at the edge of the screen, and an earlier interpreter reported
the copy it makes to do that as a sprite in its own right, at a place on the screen it never went.

A row is `width / 4` bytes and rows follow each other, which is how the blitters walk their source; the
screen's own two-bank interleave is a property of where the pixels go, not of the artwork itself.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

LOAD_ADDRESS = 0x10000
HEADER_BYTES = 512
# Black, light cyan, light magenta, white.
PALETTE = [(0, 0, 0), (85, 255, 255), (255, 85, 255), (255, 255, 255)]
# Which palette index each routine leaves see-through, or None for a straight copy.
TRANSPARENT = {"masked": 3, "keyed": 0, "plain": None}

# Where the program's data segment begins. Addresses in the code are offsets into it, and everything here
# speaks physical addresses, so this is added once rather than at every entry. Getting it wrong is easy and
# silent - the bytes still decode, they are just the wrong bytes.
DATA_SEGMENT = 0x10100

# Artwork the game keeps in an evenly strided run, listed so it can be exported whether the game was ever
# seen to draw it or not: (start address, width, height, stride between entries, how many, kind, group).
TABLES = [
    # The font, found from sub_09969: it reads a digit, shifts it left by four to index this table, and blits
    # eight rows. Ten digits and then the letters the game actually prints - it carries no alphabet it has no
    # use for. 0x129C0 onwards is not glyphs; the table is 24 entries.
    (0x12820, 8, 8, 16, 24, "plain", "Font"),
    # The dog: five frames of 32x15, drawn by the keyed routine while it is over the alley and copied plain
    # where the game has already saved the ground under it. Sizes from 0x0092xx: 4 words by 15 rows.
    (0x11380, 32, 15, 120, 5, "keyed", ""),
    # The mice on the clotheslines, drawn by the AND routine from 0x009748 onwards: 0x1E30 plus 0x20 a frame.
    (0x11F30, 16, 8, 32, 5, "masked", ""),
]

# Artwork named outright by a blitter call: `mov si, <address>` then `mov cx, <size>` then the call. Taken
# from every such call site in the disassembly, where CL is words across (eight pixels to a word) and CH
# is rows. Sizes are given the way the code gives them, as that packed CX, so they can be checked against
# it; the kind is which routine the call goes to.
DIRECT = [
    (0x064E, 0x0503, "masked"),   # 007BE6
    (0x1679, 0x1205, "keyed"),    # 0083C4, 40x18
    (0x1CF0, 0x0D02, "keyed"),    # 009508, drawn at whatever height [0x1d64] says; 13 rows is the whole of it
    (0x1D70, 0x0806, "keyed"),    # 009811, 48x8
    (0x2680, 0x1005, "plain"),    # 009DAD
    (0x296C, 0x0501, "plain"),    # 009E63
    (0x2976, 0x0C05, "plain"),    # 009E8A
    (0x29EE, 0x0804, "plain"),    # 009E9D
    (0x2A2E, 0x0B04, "plain"),
    (0x3350, 0x1205, "plain"),
    (0x3404, 0x0202, "plain"),
    (0x6152, 0x1D0B, "plain"),
    (0x63D0, 0x160E, "plain"),
    (0x6638, 0x0C03, "plain"),
    (0x6680, 0x080E, "plain"),
    (0x6760, 0x0B0C, "plain"),
    (0x6868, 0x0804, "plain"),
]

# Tables of artwork addresses, read out of the file: (address of the table, how many entries, the size the
# call site blits them at, kind). The count is where the next thing the code refers to begins.
POINTER_TABLES = [
    (0x0F7A, 12, 0x0B03, "masked"),  # the cat's walk, six frames each way, 0x008294
    (0x0F92, 8, 0x0602, "masked"),   # the cat standing: the top half, eyes, 0x0082CD
    (0x0FA2, 4, 0x0602, "masked"),   # ...and the bottom half, tail, 0x0082F2
    (0x1F5F, 3, 0x0802, "keyed"),    # 0x00985F. Its neighbour at 0x1F59 is the save buffers, not sprites
    (0x2AD1, 4, 0x0801, "plain"),
    (0x6A8F, 2, 0x0C0A, "plain"),
]

# The one table that carries its own sizes: addresses at the first, the packed CX for each at the second.
SIZED_TABLE = (0x584C, 0x5858, 6, "plain")

# Where the game saves background to draw over, as offsets into the data segment and how long each is, read
# off the `mov bp, <buffer>` before each masked and keyed call and the size the call blits. Nothing in the
# file at these offsets is a picture; what is there while the game runs is whatever was last under a sprite.
BUFFERS = [
    (0x000E, 0x400),  # the scratch buffer: clipped columns, and the 256x16 block save at 0x00D0C0
    (0x04D7, 0x40),
    (0x05FA, 0x4E),   # under the cat, walking or standing
    (0x17EE, 0x100),
    (0x1C40, 0x78),   # under the dog
    (0x1D24, 0x34),   # under the thing in the bin
    (0x1ED0, 0x60),   # under the three mice, the table at 0x1F59
]


def size_of(cx):
    """Width and height out of the packed CX the blitters take: CL words across, eight pixels a word."""
    return (cx & 0xFF) * 8, cx >> 8


def is_buffer(source):
    for offset, length in BUFFERS:
        if DATA_SEGMENT + offset <= source < DATA_SEGMENT + offset + length:
            return True
    return False


def table_entries(exe=None):
    """Everything the code names statically, in the same shape as a recorded catalogue entry."""
    out = []
    for start, width, height, stride, count, kind, group in TABLES:
        for i in range(count):
            out.append({"source": start + i * stride, "width": width, "height": height,
                        "times": 0, "masked": 0, "kind": kind, "group": group, "index": i})
    for offset, cx, kind in DIRECT:
        width, height = size_of(cx)
        out.append({"source": DATA_SEGMENT + offset, "width": width, "height": height,
                    "times": 0, "masked": 0, "kind": kind, "group": "", "index": -1})
    if exe is None:
        return out

    def word(offset):
        at = DATA_SEGMENT + offset - LOAD_ADDRESS + HEADER_BYTES
        return exe[at] | (exe[at + 1] << 8)

    for base, count, cx, kind in POINTER_TABLES:
        width, height = size_of(cx)
        for i in range(count):
            out.append({"source": DATA_SEGMENT + word(base + i * 2), "width": width, "height": height,
                        "times": 0, "masked": 0, "kind": kind, "group": "", "index": -1})
    addresses, sizes, count, kind = SIZED_TABLE
    for i in range(count):
        width, height = size_of(word(sizes + i * 2))
        out.append({"source": DATA_SEGMENT + word(addresses + i * 2), "width": width, "height": height,
                    "times": 0, "masked": 0, "kind": kind, "group": "", "index": -1})
    return out


def kind_of(entry):
    """Which routine drew it. Older catalogues only said whether the AND routine did."""
    kind = entry.get("kind")
    if kind in TRANSPARENT:
        return kind
    return "masked" if entry.get("masked", 0) >= max(1, entry.get("times", 0)) * 0.5 else "plain"


def is_phantom(entry, entries):
    """A narrower entry starting inside the first row of a wider one of the same height.

    That is what the copy the game makes to clip a sprite at the screen edge looks like when it is mistaken
    for a sprite: the source is the frame, or a word or two into its first row, and the width is what was
    left on screen. There is no artwork there in its own right.
    """
    source, width, height = entry["source"], entry["width"], entry["height"]
    for other in entries:
        if other["height"] != height or other["width"] <= width:
            continue
        if other["source"] <= source < other["source"] + other["width"] // 4:
            return True
    return False


def decode(data: bytes, width: int, height: int, kind: str):
    """The bytes of one sprite as a list of RGBA rows, or None where they run past the end of the file."""
    per_row = width // 4
    if per_row <= 0 or height <= 0 or len(data) < per_row * height:
        return None
    clear = TRANSPARENT[kind]
    rows = []
    for y in range(height):
        row = []
        for byte in data[y * per_row:(y + 1) * per_row]:
            for shift in (6, 4, 2, 0):
                index = (byte >> shift) & 3
                row.append(PALETTE[index] + (0 if index == clear else 255,))
        rows.append(row)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Export Alley Cat's sprites out of CAT.EXE")
    parser.add_argument("catalogue", help="JSON recorded from the running game by tools/sweep.gd")
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
    # screens that session reached, so the catalogue is something that grows.
    out_dir = pathlib.Path(args.out)
    before = out_dir / "index.json"
    if before.exists() and not args.fresh:
        already = json.loads(before.read_text(encoding="utf-8"))
        have = {(e["source"], e["width"], e["height"]) for e in entries}
        for entry in already:
            if (entry["source"], entry["width"], entry["height"]) not in have:
                entries.append(entry)
    # The tables go in alongside whatever was recorded, and where the two meet they are merged rather than
    # one dropped: the recorded entry has the draw counts and the table entry knows what it was drawn with
    # and what family it is in, and the table is read off the code, so its word on those is the last one.
    recorded = {(e["source"], e["width"], e["height"]): e for e in entries}
    for entry in table_entries(exe):
        key = (entry["source"], entry["width"], entry["height"])
        if key in recorded:
            recorded[key]["kind"] = entry["kind"]
            recorded[key]["group"] = entry["group"] or recorded[key].get("group", "")
            recorded[key]["index"] = entry["index"]
        else:
            entries.append(entry)
    for entry in entries:
        entry["kind"] = kind_of(entry)

    # What is not artwork: a column lifted out of a wider sprite to clip it, a buffer the game saves the
    # background in, or something the sweep saw change while the game ran, which is the same thing found
    # the other way round.
    kept = []
    dropped = {"phantom": 0, "buffer": 0}
    for entry in entries:
        if entry.get("stride", 0) or is_phantom(entry, entries):
            dropped["phantom"] += 1
        elif entry.get("buffer") or is_buffer(entry["source"]):
            dropped["buffer"] += 1
        else:
            kept.append(entry)
    entries = kept

    # One picture, one entry. The game draws some artwork a row taller each tick - the thing coming up out
    # of a bin is drawn at every height from one row to thirteen - and every height is the top of the same
    # rows from the same address, so the tallest is the whole of it and the rest are it half drawn. The
    # overlay knows to draw the top of a replacement when the game draws the top of the original.
    tallest = {}
    for entry in entries:
        key = (entry["source"], entry["width"])
        if key not in tallest or entry["height"] > tallest[key]["height"]:
            if key in tallest:
                entry["times"] = entry.get("times", 0) + tallest[key].get("times", 0)
            tallest[key] = entry
        else:
            tallest[key]["times"] = tallest[key].get("times", 0) + entry.get("times", 0)
    entries = list(tallest.values())

    out_dir.mkdir(parents=True, exist_ok=True)
    # Anything already written that is no longer catalogued is a picture of nothing, and a stale file sitting
    # beside the real ones is how a mistaken export lingers for months.
    wanted = {"sprite_%05X_%dx%d.png" % (e["source"], e["width"], e["height"]) for e in entries}
    stale = 0
    for old in out_dir.glob("sprite_*.png"):
        if old.name not in wanted:
            old.unlink()
            imported = old.with_name(old.name + ".import")
            if imported.exists():
                imported.unlink()
            stale += 1

    written, skipped = 0, 0
    index = []
    for entry in sorted(entries, key=lambda e: (e["source"], e["width"], e["height"])):
        source, width, height = entry["source"], entry["width"], entry["height"]
        at = source - LOAD_ADDRESS + HEADER_BYTES
        if at < 0 or at >= len(exe):
            skipped += 1
            continue
        rows = decode(exe[at:], width, height, entry["kind"])
        if rows is None:
            skipped += 1
            continue
        image = Image.new("RGBA", (width, height))
        image.putdata([pixel for row in rows for pixel in row])
        # Named by where it lives, because that is the only name the game gives it.
        name = "sprite_%05X_%dx%d.png" % (source, width, height)
        image.save(out_dir / name)
        index.append({"source": source, "width": width, "height": height,
                      "file": name, "times": entry.get("times", 0), "masked": entry.get("masked", 0),
                      "kind": entry["kind"], "group": entry.get("group", ""), "index": entry.get("index", -1)})
        written += 1

    (out_dir / "index.json").write_text(json.dumps(index, indent=2), encoding="utf-8")
    print("wrote %d sprites to %s; left out %d phantoms and %d buffers; removed %d stale files"
          % (written, out_dir, dropped["phantom"], dropped["buffer"], stale))
    if skipped:
        print("skipped %d whose bytes fall outside the file" % skipped)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
