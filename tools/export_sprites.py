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
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow is needed to write the PNGs: python -m pip install pillow")

    exe = pathlib.Path(args.exe).read_bytes()
    entries = json.loads(pathlib.Path(args.catalogue).read_text(encoding="utf-8"))
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
                      "file": name, "times": entry.get("times", 0), "masked": entry.get("masked", 0)})
        written += 1

    (out / "index.json").write_text(json.dumps(index, indent=2), encoding="utf-8")
    print("wrote %d sprites to %s" % (written, out))
    if skipped:
        print("skipped %d whose bytes fall outside the file" % skipped)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
