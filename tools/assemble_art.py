#!/usr/bin/env python3
"""Assemble game sheets from Aseprite sources and Blender renders.

Usage: assemble_art.py <terrain.png> <renders_dir> <build_dir>

Inputs
  terrain.png   export of assets/aseprite/terrain.aseprite (8x8 tiles; the
                prop cells hold the ground the props stand on)
  renders_dir   assets/renders (tools/blender/hfm_render.py output)
Outputs (in build_dir, palette-exact PNGs, then clamped by Aseprite)
  norway.png    tile sheet: terrain + pine/tower/truck/rock composited on it
  fx.png        barrel + 3 explosion frames (12x16 masked cells)
  portraits.png HUD portraits, 3 x 16x24
  title.png     menu banner, 160x56
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelize import pixelize  # noqa: E402
from sheetlib import BLK, BRED, BYEL, PYEL, RED, SKIN, Canvas, crop, from_png, save_sheet  # noqa: E402
from tiles_def import SHEET_COLS, STAMPS, TILE_NAMES  # noqa: E402


def render_canvas(path, priority=()):
    rows = pixelize(path, priority=priority)
    cv = Canvas(len(rows[0]), len(rows))
    for y, row in enumerate(rows):
        cv.px[y] = list(row)
    return cv


def tiles_sheet(terrain_png, renders):
    sheet = from_png(terrain_png)
    tiles = [crop(sheet, (i % SHEET_COLS) * 8, (i // SHEET_COLS) * 8, 8, 8)
             for i in range(len(TILE_NAMES))]
    for name, (first, w, h) in STAMPS.items():
        art = render_canvas(os.path.join(renders, name, name + ".png"), priority=(BYEL, BRED))
        if name != "tower":                       # the lattice is drawn in black already
            art.outline(BLK)
        base = TILE_NAMES.index(first)
        for ty in range(h):
            for tx in range(w):
                cell = tiles[base + ty * w + tx]  # ground painted in Aseprite
                for y in range(8):
                    for x in range(8):
                        p = art.get(tx * 8 + x, ty * 8 + y)
                        if p is not None:
                            cell.px[y][x] = p
    return tiles


def fx_sheet(renders):
    cells = []
    for name, sub in (("barrel", "barrel"), ("frame1", "explosion"), ("frame2", "explosion"),
                      ("frame3", "explosion")):
        cv = render_canvas(os.path.join(renders, sub, name + ".png"), priority=(BYEL, PYEL))
        cv.outline(BLK)
        cells.append(cv)
    return cells


def portraits(renders):
    return [render_canvas(os.path.join(renders, "portraits", s + ".png"), priority=(BLK, RED),
                          ) for s in ("beret", "marine", "sniper")]


def title(renders):
    cv = render_canvas(os.path.join(renders, "banner", "banner.png"), priority=(BYEL, PYEL))
    # black outline around the logo (yellow letters + red drop shadow)
    logo = {BYEL, RED}
    add = [(x, y) for y in range(cv.h) for x in range(cv.w)
           if cv.px[y][x] not in logo and any(cv.get(x + dx, y + dy) in logo
                                              for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
           and y < 44]                           # not around the characters below
    for x, y in add:
        cv.px[y][x] = BLK
    return [cv]


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    terrain_png, renders, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    save_sheet(tiles_sheet(terrain_png, renders), os.path.join(out, "norway.png"), cols=SHEET_COLS)
    save_sheet(fx_sheet(renders), os.path.join(out, "fx.png"))
    save_sheet(portraits(renders), os.path.join(out, "portraits.png"))
    save_sheet(title(renders), os.path.join(out, "title.png"))
    print(f"assemble_art: norway, fx, portraits, title -> {out}")


if __name__ == "__main__":
    main()
