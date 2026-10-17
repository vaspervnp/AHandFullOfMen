#!/usr/bin/env python3
"""Assemble game sheets from Aseprite sources and Blender renders.

Usage: assemble_art.py <terrain.png> <renders_dir> <build_dir>

Inputs
  terrain.png   export of assets/aseprite/terrain.aseprite (8x8 tiles; the
                prop cells hold the ground the props stand on)
  renders_dir   assets/renders (tools/blender/hfm_render.py output)
Outputs (in build_dir, palette-exact PNGs, then clamped by Aseprite)
  norway.png    tile sheet: terrain + pine/tower/truck/rock composited on it
  fx.png        barrel, 3 explosion frames, bear trap, time bomb (12x16 masked cells)
  portraits.png HUD portraits, 5 x 16x24 (ROLE_* order)
  title.png     menu banner, 160x56
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelize import pixelize  # noqa: E402
from sheetlib import BLK, BRED, BYEL, PYEL, RED, SKIN, WHT, Canvas, crop, from_png, save_sheet  # noqa: E402
from tiles_def import SHEET_COLS, STAMP_GROUND, STAMPS, TILE_NAMES  # noqa: E402


def render_canvas(path, priority=(), pcover=None):
    rows = pixelize(path, priority=priority, pcover=pcover)
    cv = Canvas(len(rows[0]), len(rows))
    for y, row in enumerate(rows):
        cv.px[y] = list(row)
    return cv


def tiles_sheet(terrain_png, renders):
    sheet = from_png(terrain_png)
    cell = lambda i: crop(sheet, (i % SHEET_COLS) * 8, (i // SHEET_COLS) * 8, 8, 8)  # noqa: E731
    ground = {i: "snow" for i in range(len(TILE_NAMES))}
    for name, (first, w, h) in STAMPS.items():
        for k in range(w * h):
            g = STAMP_GROUND.get(name, "snow")      # one ground, or one per row
            ground[TILE_NAMES.index(first) + k] = g if isinstance(g, str) else g[k // w]
    tiles = []
    for i in range(len(TILE_NAMES)):     # cells not painted in Aseprite: plain ground
        c = cell(i)
        tiles.append(c if any(p is not None for row in c.px for p in row)
                     else cell(TILE_NAMES.index(ground[i])))
    for name, (first, w, h) in STAMPS.items():
        art = render_canvas(os.path.join(renders, name, name + ".png"), priority=(BLK, BYEL, BRED), pcover=4)
        art.outline(BLK)                          # (black first: keeps the little eyes)
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
                      ("frame3", "explosion"), ("trap", "trap"), ("bomb", "bomb")):
        cv = render_canvas(os.path.join(renders, sub, name + ".png"), priority=(BLK, BYEL, PYEL), pcover=4)
        cv.outline(BLK)
        cells.append(cv)
    return cells


def portraits(renders):
    return [render_canvas(os.path.join(renders, "portraits", s + ".png"), priority=(WHT, BLK, RED),
                          ) for s in ("beret", "marine", "sniper", "sapper", "spy")]


def title(renders, out):
    """The Blender banner with the pixel-art logo (logo.aseprite, exported
    to <out>/logo.png by render_assets.sh) on top."""
    cv = render_canvas(os.path.join(renders, "banner", "banner.png"), priority=(BYEL, PYEL))
    logo = from_png(os.path.join(out, "logo.png"))
    for y in range(cv.h):
        for x in range(cv.w):
            if logo.px[y][x] is not None:
                cv.px[y][x] = logo.px[y][x]
    return [cv]


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    terrain_png, renders, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    save_sheet(tiles_sheet(terrain_png, renders), os.path.join(out, "norway.png"), cols=SHEET_COLS)
    save_sheet(fx_sheet(renders), os.path.join(out, "fx.png"))
    save_sheet(portraits(renders), os.path.join(out, "portraits.png"))
    save_sheet(title(renders, out), os.path.join(out, "title.png"))
    print(f"assemble_art: norway, fx, portraits, title -> {out}")


if __name__ == "__main__":
    main()
