#!/usr/bin/env python3
"""Assemble Blender renders into the game's sprite sheet layout.

Usage: renders2sheet.py <renders_dir> <subject> <out.png>

Reads <renders_dir>/<subject>/<pose>_<dir>.png (from tools/blender/hfm_render.py),
pixelizes each to 12x16 Mode 0 pixels, adds the black outline and writes a
37-cell sheet (one row of 12x16 cells):
   0- 4 stand   N NE E SE S
   5- 9 walk A  N NE E SE S
  10-14 walk B  N NE E SE S
  15-17 crawl A N E S
  18-20 crawl B N E S
  21-23 attack  N E S
  24    corpse
  25-27 stand   NW W SW   (mirrors of NE E SE)
  28-30 walk A  NW W SW
  31-33 walk B  NW W SW
  34    crawl A W
  35    crawl B W
  36    attack  W
The game picks frames through the ftab_* tables in src/data/luts.asm.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sheetlib import BLK, BYEL, SKIN, Canvas, mirror, save_sheet  # noqa: E402
from pixelize import pixelize  # noqa: E402

DIRS5 = ["N", "NE", "E", "SE", "S"]


def cell(renders, subject, name):
    rows = pixelize(os.path.join(renders, subject, name + ".png"), priority=(BLK, SKIN, BYEL))  # eyes first
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
