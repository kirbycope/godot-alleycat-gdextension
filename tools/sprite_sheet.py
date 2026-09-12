#!/usr/bin/env python3
"""Draw the exported sprites as labelled contact sheets, so they can be looked at and matched up.

    python tools/sprite_sheet.py [--out <dir>]

The game has no names for its artwork, only the address it copies from, so an address is all a slot in
resources/artwork.tres has to go on. These sheets are how that address becomes something recognisable: every
exported sprite at a readable size with its address, its shape, how often it was drawn and whether it is a
mask. Find the one you want, note the address, and put your own picture in that slot.

Each cell is drawn on mid grey on purpose. The artwork uses all four CGA colours including black, and black
sprites - the player's cat among them - vanish on a dark background and white ones vanish on a light one.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

CELL_BG = (150, 150, 158, 255)
SHEET_BG = (28, 28, 34, 255)
LABEL = (225, 227, 235, 255)
DIM = (170, 174, 188, 255)


def main() -> int:
    parser = argparse.ArgumentParser(description="Contact sheets of the exported sprites")
    parser.add_argument("--sprites", default="addons/godot_alleycat_gdextension/assets/artwork/original")
    parser.add_argument("--out", default="addons/godot_alleycat_gdextension/assets/artwork")
    parser.add_argument("--per-sheet", type=int, default=48)
    args = parser.parse_args()

    try:
        from PIL import Image, ImageDraw
    except ImportError:
        sys.exit("Pillow is needed: python -m pip install pillow")

    root = pathlib.Path(args.sprites)
    index = json.loads((root / "index.json").read_text(encoding="utf-8"))
    index.sort(key=lambda e: (e["source"], e["width"], e["height"]))

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for sheet_no, start in enumerate(range(0, len(index), args.per_sheet), start=1):
        page = index[start:start + args.per_sheet]
        cols = 6
        rows = (len(page) + cols - 1) // cols
        # Every cell the same size, so the sheet is a grid rather than a ragged pile.
        cell_w, cell_h, label_h, pad = 176, 120, 30, 8
        sheet = Image.new("RGBA", (cols * cell_w, rows * (cell_h + label_h)), SHEET_BG)
        draw = ImageDraw.Draw(sheet)
        for i, entry in enumerate(page):
            cx = (i % cols) * cell_w
            cy = (i // cols) * (cell_h + label_h)
            draw.rectangle([cx + pad, cy + pad, cx + cell_w - pad, cy + cell_h - pad], fill=CELL_BG)
            image = Image.open(root / entry["file"]).convert("RGBA")
            # As large as fits the cell at a whole-number scale, so the pixels stay square and sharp.
            scale = max(1, min((cell_w - pad * 4) // max(image.width, 1),
                               (cell_h - pad * 4) // max(image.height, 1)))
            big = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
            sheet.alpha_composite(big, (cx + (cell_w - big.width) // 2, cy + (cell_h - big.height) // 2))
            mask = entry["masked"] >= max(1, entry["times"]) * 0.5
            draw.text((cx + pad, cy + cell_h - 2), "0x%05X  %dx%d" % (entry["source"], entry["width"], entry["height"]), fill=LABEL)
            draw.text((cx + pad, cy + cell_h + 12), "drawn %d%s" % (entry["times"], "  (mask)" if mask else ""), fill=DIM)
        name = out / ("sprite_sheet_%d.png" % sheet_no)
        sheet.save(name)
        written.append(name)
    print("wrote %d sheet(s) covering %d sprites:" % (len(written), len(index)))
    for name in written:
        print("  %s" % name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
