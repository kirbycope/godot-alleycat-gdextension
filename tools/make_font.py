#!/usr/bin/env python3
"""Draw the letters Alley Cat does not have, in the style of the ones it does.

    python tools/make_font.py            # writes the preview and the GDScript table

The game carries twelve letters - A C E H I K L M S T U V - plus the digits, an apostrophe and a hyphen,
because that is everything its fence graffiti spells and not one glyph more. Anything else written on the
fence needs a glyph that does not exist, so these are drawn to fill the gaps: B D F G J N O P Q R W X Y Z.

They are placeholders in the honest sense. The real ones are hand-drawn in a loose graffiti hand and no two
strokes match; these are built from an upright skeleton with a common drift, which gets the weight about
right and the character wrong. They read correctly at 8x8 on a fence and are meant to be redrawn by someone
with an eye for it.

There is no lean to copy, which is worth saying because it is easy to think there is. Measured across all 24
of the game's glyphs - the leftmost inked column of the top row against the leftmost of the bottom row - the
letters drift +0.26 columns, which is nothing. They scatter either way: H and the apostrophe lean back three
columns, V leans forward three, and a third of them are dead upright. Taking the slope off any one letter
and applying it to fourteen gives a set that leans harder and more consistently than anything the game has,
and it shows. A drift of one column over the eight rows is the median and is all that is applied here.
"""

from __future__ import annotations

import json
import pathlib

# Ink is index 0 and the background is index 1: the glyphs are blitted whole rather than masked, so each
# carries the fence's own cyan around its letter. `#` is ink.
INK, PAPER = 0, 1

# Upright skeletons, six columns wide so the one column of drift still fits the eight a cell has.
LETTERS = {
    "B": ["####..", "##..#.", "##..#.", "####..", "##..#.", "##..#.", "####..", "......"],
    "D": ["####..", "##..#.", "##...#", "##...#", "##...#", "##..#.", "####..", "......"],
    "F": ["#####.", "##....", "##....", "####..", "##....", "##....", "##....", "......"],
    "G": [".####.", "##....", "##....", "##.###", "##..##", "##..##", ".####.", "......"],
    "J": ["..####", "....##", "....##", "....##", "##..##", "##..##", ".####.", "......"],
    "N": ["##...#", "###..#", "####.#", "##.###", "##..##", "##...#", "##...#", "......"],
    "O": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####.", "......"],
    "P": ["####..", "##..#.", "##..#.", "####..", "##....", "##....", "##....", "......"],
    "Q": [".####.", "##..##", "##..##", "##..##", "##.###", "##..##", ".#####", "......"],
    "R": ["####..", "##..#.", "##..#.", "####..", "##.#..", "##..#.", "##..##", "......"],
    "W": ["##..##", "##..##", "##..##", "##.###", "######", "###.##", "##..##", "......"],
    "X": ["##..##", ".####.", "..##..", "..##..", ".####.", "##..##", "##..##", "......"],
    "Y": ["##..##", ".####.", "..##..", "..##..", "..##..", "..##..", "..##..", "......"],
    "Z": ["######", "....##", "...##.", "..##..", ".##...", "##....", "######", "......"],
}

## Where the new glyphs go in the machine: past the end of the load image, which is 54,555 bytes, and so
## past anything the program itself put in memory. Measured rather than assumed - after a full play session
## every one of the 11,237 bytes from here to the top of the data segment is still zero.
EXTRA_GLYPHS_AT = 0xD800  # an offset in the data segment, which begins at physical 0x10100
DATA_SEGMENT = 0x10100

## Where the catalogue is told about them. They cannot go in with the rest: everything in
## `assets/artwork/original` is sliced out of CAT.EXE by `tools/export_sprites.py`, and these are not in
## CAT.EXE at all - they are written into the machine's memory while it runs. So they are exported here, to
## a folder of their own, and `build_artwork_resource.py` reads both.
ADDED = pathlib.Path("addons/godot_alleycat_gdextension/assets/artwork/added")


def sheared(rows: list[str]) -> list[str]:
    """The same letter with the drift the game's own letters have on average: one column, top to bottom.

    Not a lean. See the note at the top of this file - there is no consistent slope in the game's font, and
    shearing to match one letter's is what made the first attempt at these look wrong.
    """
    out = []
    for y, row in enumerate(rows):
        shift = y // 4
        out.append(("." * shift + row)[:8].ljust(8, "."))
    return out


def as_bytes(rows: list[str]) -> bytes:
    """One glyph as the machine holds it: two bytes a row, four pixels a byte, two bits each."""
    data = bytearray()
    for row in rows:
        for half in (row[:4], row[4:8]):
            byte = 0
            for pixel in half.ljust(4, "."):
                byte = (byte << 2) | (INK if pixel == "#" else PAPER)
            data.append(byte)
    return bytes(data)


def main() -> int:
    order = sorted(LETTERS)
    glyphs = {letter: as_bytes(sheared(LETTERS[letter])) for letter in order}

    # Static functions rather than constants: GDScript will not resolve a constant of a typed array from
    # another script, whether it is preloaded or reached through a class_name, and a static call resolves.
    lines = [
        "## The letters the game does not carry, in the order [method glyphs] returns them.",
        "static func letters() -> String:",
        "\treturn \"%s\"" % "".join(order),
        "",
        "",
        "## One entry a letter, sixteen bytes each: two a row, four pixels a byte, ink where the letter is",
        "## and the fence's own colour around it, which is what the game's own glyphs hold.",
        "static func glyphs() -> Array[PackedByteArray]:",
        "\tvar out: Array[PackedByteArray] = []",
    ]
    for letter in order:
        body = ", ".join(str(b) for b in glyphs[letter])
        lines.append("\tout.append(PackedByteArray([%s]))  # %s" % (body, letter))
    lines.append("\treturn out")
    table = pathlib.Path("addons/godot_alleycat_gdextension/scripts/alley_cat_extra_font.gd")
    # A class_name rather than something to preload: GDScript will not resolve a constant through a
    # script-typed constant, so the table has to be a named class for anything to read it at parse time.
    head = [
        "class_name AlleyCatExtraFont",
        "extends RefCounted",
        "## " + __doc__.strip().splitlines()[0],
        "##",
        "## Generated by tools/make_font.py. Draw there, not here.",
        "",
    ]
    table.write_text("\n".join(head + lines) + "\n", encoding="utf-8")
    print("wrote %s with %d letters" % (table, len(order)))

    try:
        from PIL import Image
    except ImportError:
        return 0
    palette = [(0, 0, 0), (85, 255, 255), (255, 85, 255), (255, 255, 255)]
    zoom, cols = 8, 7
    rows_of = (len(order) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (8 * zoom + 4), rows_of * (8 * zoom + 4)), (60, 60, 64))
    for i, letter in enumerate(order):
        cell = Image.new("RGB", (8, 8))
        pixels = cell.load()
        for y in range(8):
            for x in range(8):
                byte = glyphs[letter][y * 2 + x // 4]
                pixels[x, y] = palette[(byte >> (6 - (x % 4) * 2)) & 3]
        cell = cell.resize((8 * zoom, 8 * zoom), Image.NEAREST)
        sheet.paste(cell, ((i % cols) * (8 * zoom + 4) + 2, (i // cols) * (8 * zoom + 4) + 2))
    preview = pathlib.Path("addons/godot_alleycat_gdextension/assets/artwork/extra_font.png")
    sheet.save(preview)
    print("wrote %s" % preview)

    # And one PNG each, at the address the glyph will live at once it is in the machine, so the browser can
    # show them beside the game's own and anybody can drop a better drawing over one.
    ADDED.mkdir(parents=True, exist_ok=True)
    index = []
    for i, letter in enumerate(order):
        source = DATA_SEGMENT + EXTRA_GLYPHS_AT + i * 16
        cell = Image.new("RGBA", (8, 8))
        pixels = cell.load()
        for y in range(8):
            for x in range(8):
                byte = glyphs[letter][y * 2 + x // 4]
                pixels[x, y] = palette[(byte >> (6 - (x % 4) * 2)) & 3] + (255,)
        name = "sprite_%05X_8x8.png" % source
        cell.save(ADDED / name)
        index.append({
            "source": source, "width": 8, "height": 8, "file": "added/" + name,
            "times": 0, "masked": 0, "group": "Font", "label": "Letter %s" % letter,
            "note": "8x8, drawn rather than found: written into the machine at 0x%05X" % source,
        })
    (ADDED / "index.json").write_text(json.dumps(index, indent=2), encoding="utf-8")
    print("wrote %d glyph PNGs to %s" % (len(index), ADDED))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
