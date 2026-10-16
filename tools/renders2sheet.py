#!/usr/bin/env python3
"""Assemble Blender renders into the game's sprite sheet layout.

Usage: renders2sheet.py <renders_dir> <subject> <out.png>

Reads <renders_dir>/<subject>/<pose>_<dir>.png (from tools/blender/hfm_render.py),
pixelizes each to 12x16 Mode 0 pixels, adds the black outline and writes a
37-cell sheet in the layout documented in tools/gen_art.py (west-facing
frames are mirrors of the east-facing ones).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_art import BLK, BYEL, SKIN, Canvas, mirror, save_sheet  # noqa: E402
from pixelize import pixelize  # noqa: E402

DIRS5 = ["N", "NE", "E", "SE", "S"]


def cell(renders, subject, name):
    rows = pixelize(os.path.join(renders, subject, name + ".png"), priority=(SKIN, BYEL))
    cv = Canvas(12, 16)
    for y, row in enumerate(rows[:16]):
        for x, p in enumerate(row[:12]):
            cv.px[y][x] = p
    # keep a transparent margin for the outline, then draw it
    for y in range(16):
        for x in (0, 11):
            cv.px[y][x] = None
    cv.px[0] = [None] * 12
    cv.outline(BLK)
    return cv


def build(renders, subject):
    c = lambda n: cell(renders, subject, n)  # noqa: E731
    cells = [c(f"stand_{d}") for d in DIRS5]
    cells += [c(f"walk1_{d}") for d in DIRS5]
    cells += [c(f"walk2_{d}") for d in DIRS5]
    cells += [c(f"crawl1_{d}") for d in ("N", "E", "S")]
    cells += [c(f"crawl2_{d}") for d in ("N", "E", "S")]
    cells += [c(f"attack_{d}") for d in ("N", "E", "S")]
    cells.append(c("corpse_S"))
    for base in (0, 5, 10):
        cells += [mirror(cells[base + i]) for i in (1, 2, 3)]
    cells += [mirror(cells[16]), mirror(cells[19]), mirror(cells[22])]
    assert len(cells) == 37
    return cells


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    renders, subject, out = sys.argv[1:]
    save_sheet(build(renders, subject), out)
    print(f"renders2sheet: {subject} -> {out}")


if __name__ == "__main__":
    main()
