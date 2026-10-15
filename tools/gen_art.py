#!/usr/bin/env python3
"""Procedural placeholder art for A Handful of Men.

Writes RGB PNG sheets (exact game palette colours, #FF00FF = transparent) plus
png2cpc manifests into assets/. These stand in for the Blender -> Aseprite
pre-render pipeline: any replacement sheet only has to keep the same cell
layout to drop straight into the build.

Sprite sheet layout (12x16 cells, one row per sheet, 25 frames):
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
Mirrored frames are pre-generated so the Z80 blitter never has to flip.
"""
import json
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpcpal import GAME_RGB, TRANSPARENT  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(ROOT, "assets")

# Pen names
BLK, WHT, SNOWSH, SKY, BLUE, GREY, GRN, TEAL, RED, ORA, SKIN, OLIVE, BRED, BYEL, BBLU, PYEL = range(16)
T = None  # transparent


class Canvas:
    def __init__(self, w, h, fill=T):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return T

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def outline(self, c=BLK):
        """Black 4-neighbour outline around every opaque pixel."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is T and any(
                        self.get(x + dx, y + dy) not in (T, c)
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    add.append((x, y))
        for x, y in add:
            self.px[y][x] = c

    def paste(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                if other.px[y][x] is not T:
                    self.set(ox + x, oy + y, other.px[y][x])


def save_sheet(cells, path, cols=None):
    cols = cols or len(cells)
    w, h = cells[0].w, cells[0].h
    rows = (len(cells) + cols - 1) // cols
    img = Image.new("RGB", (w * cols, h * rows), TRANSPARENT)
    for i, cv in enumerate(cells):
        ox, oy = (i % cols) * w, (i // cols) * h
        for y in range(h):
            for x in range(w):
                c = cv.px[y][x]
                img.putpixel((ox + x, oy + y), TRANSPARENT if c is T else GAME_RGB[c])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    # 2:1 preview for humans (Mode 0 pixels are twice as wide as tall)
    img.resize((img.width * 4, img.height * 2), Image.NEAREST).save(path.replace(".png", "_preview.png"))


# --------------------------------------------------------------------------
# Characters
# --------------------------------------------------------------------------

class Look:
    def __init__(self, hat, hat2, uniform, shade, pack, weapon, helmet=False):
        self.hat, self.hat2, self.uniform, self.shade = hat, hat2, uniform, shade
        self.pack, self.weapon, self.helmet = pack, weapon, helmet


BERET = Look(hat=TEAL, hat2=TEAL, uniform=GRN, shade=TEAL, pack=OLIVE, weapon=WHT)
GUARD = Look(hat=GREY, hat2=GREY, uniform=OLIVE, shade=GREY, pack=RED, weapon=RED, helmet=True)


def legs_front(cv, lk, step):
    """Legs seen from front/back; step 0 = together, 1/2 = stride."""
    if step == 0:
        cv.rect(4, 10, 5, 13, lk.uniform)
        cv.rect(6, 10, 7, 13, lk.uniform)
    elif step == 1:
        cv.rect(4, 10, 5, 13, lk.uniform)
        cv.rect(6, 10, 7, 12, lk.uniform)
    else:
        cv.rect(4, 10, 5, 12, lk.uniform)
        cv.rect(6, 10, 7, 13, lk.uniform)
    cv.set(5, 11, lk.shade)
    cv.set(6, 11, lk.shade)


def head(cv, lk, x, facing):
    """Head with hat/helmet at column x (2 px wide face)."""
    if lk.helmet:
        cv.rect(x - 1, 1, x + 2, 2, lk.hat)
        cv.set(x - 1, 3, lk.hat)
        cv.set(x + 2, 3, lk.hat)
    else:
        cv.rect(x, 1, x + 1, 1, lk.hat)
        cv.rect(x - 1, 2, x + 2, 2, lk.hat2)
    if facing == "back":
        cv.rect(x, 3, x + 1, 4, lk.hat if lk.helmet else RED)
    else:
        cv.rect(x, 3, x + 1, 4, SKIN)
    if facing == "side":
        cv.set(x + 2, 3, SKIN)


def person(lk, d, step=0, pose="stand"):
    cv = Canvas(12, 16)
    if pose == "crawl":
        return crawler(lk, d, step)
    if pose == "corpse":
        return corpse(lk)
    if d in ("S", "N"):
        back = d == "N"
        head(cv, lk, 5, "back" if back else "front")
        cv.rect(4, 5, 7, 9, lk.uniform)          # torso
        cv.rect(3, 5, 3, 8, lk.uniform)          # arms
        cv.rect(8, 5, 8, 8, lk.uniform)
        cv.set(3, 9, SKIN)
        cv.set(8, 9, SKIN)
        if back:
            cv.rect(5, 5, 6, 8, lk.pack)          # backpack
        else:
            cv.rect(4, 9, 7, 9, lk.shade)        # belt
            cv.set(5, 6, lk.shade)
        if pose == "attack":
            cv.rect(8, 3, 8, 6, lk.uniform)      # raised arm
            cv.set(8, 2, SKIN)
            cv.set(9, 1, lk.weapon)
            cv.set(8, 9, T)
            cv.set(8, 8, T)
            cv.set(8, 7, T)
        legs_front(cv, lk, step)
    elif d == "E":
        head(cv, lk, 5, "side")
        cv.rect(5, 5, 6, 9, lk.uniform)
        cv.rect(4, 5, 4, 8, lk.pack)
        if pose == "attack":
            cv.rect(7, 6, 8, 6, lk.uniform)
            cv.set(9, 6, SKIN)
            cv.rect(10, 6, 11, 6, lk.weapon)
        else:
            cv.rect(6, 5, 6, 8, lk.shade)        # arm
            cv.set(7, 8, SKIN)
            if lk.helmet:
                cv.rect(7, 4, 7, 7, lk.weapon)   # slung rifle
        if step == 0:
            cv.rect(5, 10, 6, 13, lk.uniform)
        elif step == 1:
            cv.rect(6, 10, 7, 12, lk.uniform)
            cv.set(8, 13, lk.uniform)
            cv.rect(4, 10, 5, 12, lk.shade)
            cv.set(3, 13, lk.shade)
        else:
            cv.rect(5, 10, 6, 13, lk.uniform)
            cv.set(6, 12, lk.shade)
    elif d in ("SE", "NE"):
        back = d == "NE"
        head(cv, lk, 5 if back else 6, "back" if back else "front")
        if not back:
            cv.set(5, 3, SKIN)
        cv.rect(4, 5, 7, 9, lk.uniform)
        cv.rect(8, 5, 8, 8, lk.shade)
        cv.set(8, 9, SKIN)
        cv.rect(3, 5, 3, 7, lk.uniform)
        if back:
            cv.rect(4, 5, 5, 8, lk.pack)
        else:
            cv.rect(4, 9, 7, 9, lk.shade)
        legs_front(cv, lk, step)
        if step == 1:
            cv.set(8, 13, lk.uniform)
    cv.outline()
    return cv


def crawler(lk, d, step):
    cv = Canvas(12, 16)
    if d == "E":
        cv.rect(8, 10, 9, 11, lk.hat)
        cv.set(9, 12, SKIN)
        cv.rect(3, 11, 7, 12, lk.uniform)
        cv.rect(4, 10, 6, 10, lk.pack)
        if step:
            cv.rect(1, 12, 2, 12, lk.uniform)
            cv.set(10, 11, SKIN)
        else:
            cv.rect(1, 11, 2, 11, lk.uniform)
            cv.set(10, 12, SKIN)
    else:
        top = d == "N"
        # seen from above: head at the facing end
        hy = 3 if top else 12
        cv.rect(5, hy, 6, hy + 1, lk.hat if top else SKIN)
        by0, by1 = (5, 10) if top else (6, 11)
        cv.rect(5, by0, 6, by1, lk.uniform)
        cv.rect(5, by0 + 1, 6, by0 + 2, lk.pack)
        ly = 11 if top else 3
        if step:
            cv.rect(4, ly, 4, ly + 2, lk.uniform)
            cv.rect(7, ly, 7, ly + 1, lk.uniform)
        else:
            cv.rect(4, ly, 4, ly + 1, lk.uniform)
            cv.rect(7, ly, 7, ly + 2, lk.uniform)
        ay = 5 if top else 10
        cv.set(4, ay, SKIN)
        cv.set(7, ay, SKIN)
    cv.outline()
    return cv


def corpse(lk):
    cv = Canvas(12, 16)
    cv.rect(1, 11, 2, 12, lk.hat)
    cv.rect(3, 11, 8, 12, lk.uniform)
    cv.rect(9, 11, 10, 11, lk.uniform)
    cv.rect(9, 12, 10, 12, lk.shade)
    cv.outline()
    cv.set(4, 14, BRED)
    cv.set(5, 14, BRED)
    cv.set(3, 13, BRED)
    return cv


def sprite_sheet(lk):
    dirs5 = ["N", "NE", "E", "SE", "S"]
    cells = [person(lk, d, 0) for d in dirs5]
    cells += [person(lk, d, 1) for d in dirs5]
    cells += [person(lk, d, 2) for d in dirs5]
    cells += [person(lk, d, 0, "crawl") for d in ("N", "E", "S")]
    cells += [person(lk, d, 1, "crawl") for d in ("N", "E", "S")]
    cells += [person(lk, d, 0, "attack") for d in ("N", "E", "S")]
    cells.append(person(lk, "S", 0, "corpse"))
    for base in (0, 5, 10):                       # NW W SW from NE E SE
        cells += [mirror(cells[base + i]) for i in (1, 2, 3)]
    cells += [mirror(cells[16]), mirror(cells[19]), mirror(cells[22])]
    return cells


def mirror(cv):
    out = Canvas(cv.w, cv.h)
    for y in range(cv.h):
        out.px[y] = cv.px[y][::-1]
    return out


def cursor_sheet():
    cells = []
    # 0 crosshair
    cv = Canvas(8, 8)
    for i in (0, 1, 6, 7):
        cv.set(i, 3, BYEL)
        cv.set(3, i, BYEL) if i != 7 else None
    cv.set(4, 3, T)
    for i in (0, 1, 5, 6):
        cv.set(3, i, BYEL)
    cv.set(3, 3, BRED)
    cells.append(cv)
    # 1 knife / attack target
    cv = Canvas(8, 8)
    for i in range(7):
        cv.set(i, i, BRED)
        cv.set(6 - i, i, BRED)
    cells.append(cv)
    # 2 alert "!"
    cv = Canvas(8, 8)
    cv.rect(3, 0, 4, 4, BRED)
    cv.rect(3, 6, 4, 6, BRED)
    cv.outline(BYEL)
    cells.append(cv)
    # 3 suspicious "?"
    cv = Canvas(8, 8)
    cv.rect(2, 0, 5, 0, BYEL)
    cv.set(5, 1, BYEL)
    cv.set(5, 2, BYEL)
    cv.rect(3, 3, 4, 3, BYEL)
    cv.set(3, 4, BYEL)
    cv.set(3, 6, BYEL)
    cv.outline(BLK)
    cells.append(cv)
    return cells


# --------------------------------------------------------------------------
# Tiles (8x8)
# --------------------------------------------------------------------------

# Order matters: tile ids are referenced by tools/map2asm.py legend and
# src/data/tileattrs.asm flags.
TILE_NAMES = [
    "snow", "snow_speck", "snow_shade", "road", "ice", "water", "bank_n", "bank_s",
    "rock", "fence_h", "fence_v", "wall", "roof", "roof_edge", "door", "bridge",
    "sandbag", "tracks",
    "pine0", "pine1", "pine2", "pine3", "pine4", "pine5",          # 2x3 stamp
    "tower0", "tower1", "tower2", "tower3", "tower4", "tower5", "tower6", "tower7",  # 2x4
    "rubble", "gate", "hud_bg", "hud_edge",
]


def tile(seed):
    random.seed(seed)
    return Canvas(8, 8, WHT)


def snow_tile(seed, density=0.08, shade=SNOWSH):
    cv = tile(seed)
    for y in range(8):
        for x in range(8):
            if random.random() < density:
                cv.set(x, y, shade)
    return cv


def make_tiles():
    tiles = {}
    tiles["snow"] = snow_tile(1, 0.03)
    tiles["snow_speck"] = snow_tile(2, 0.12)
    cv = snow_tile(3, 0.55)
    tiles["snow_shade"] = cv
    cv = Canvas(8, 8, SNOWSH)
    random.seed(4)
    for y in range(8):
        for x in range(8):
            r = random.random()
            if r < 0.15:
                cv.set(x, y, GREY)
            elif r < 0.25:
                cv.set(x, y, WHT)
    tiles["road"] = cv
    cv = Canvas(8, 8, SNOWSH)
    for x, y in ((1, 1), (2, 2), (3, 2), (5, 5), (6, 6), (4, 6), (0, 4)):
        cv.set(x, y, SKY)
    cv.set(6, 1, WHT)
    tiles["ice"] = cv
    cv = Canvas(8, 8, BLUE)
    for x, y in ((1, 2), (2, 2), (5, 5), (6, 5), (3, 7)):
        cv.set(x, y, SKY)
    tiles["water"] = cv
    cv = Canvas(8, 8, BLUE)
    cv.rect(0, 0, 7, 2, WHT)
    for x in range(8):
        cv.set(x, 3 if x % 3 else 2, SNOWSH)
    cv.set(2, 6, SKY)
    tiles["bank_n"] = cv
    cv = Canvas(8, 8, BLUE)
    cv.rect(0, 5, 7, 7, WHT)
    for x in range(8):
        cv.set(x, 4 if x % 3 else 5, SNOWSH)
    cv.set(5, 1, SKY)
    tiles["bank_s"] = cv
    cv = snow_tile(5, 0.02)
    cv.rect(1, 2, 6, 6, GREY)
    cv.rect(2, 1, 5, 1, GREY)
    cv.rect(2, 2, 3, 3, WHT)
    cv.rect(4, 5, 6, 6, BLK)
    cv.set(1, 7, SNOWSH)
    tiles["rock"] = cv
    cv = snow_tile(6, 0.03)
    cv.rect(0, 2, 7, 2, RED)
    cv.rect(0, 5, 7, 5, RED)
    cv.rect(1, 1, 1, 7, ORA)
    cv.rect(5, 1, 5, 7, ORA)
    tiles["fence_h"] = cv
    cv = snow_tile(7, 0.03)
    cv.rect(3, 0, 4, 7, RED)
    cv.set(3, 1, ORA)
    cv.set(3, 5, ORA)
    tiles["fence_v"] = cv
    cv = Canvas(8, 8, RED)
    for y in range(0, 8, 2):
        cv.rect(0, y, 7, y, ORA)
    cv.set(7, 1, BLK)
    cv.set(3, 3, BLK)
    cv.set(7, 5, BLK)
    cv.set(3, 7, BLK)
    tiles["wall"] = cv
    cv = Canvas(8, 8, GREY)
    for y in range(0, 8, 3):
        cv.rect(0, y, 7, y, WHT)
    tiles["roof"] = cv
    cv = Canvas(8, 8, GREY)
    cv.rect(0, 0, 7, 3, WHT)
    cv.rect(0, 6, 7, 7, BLK)
    tiles["roof_edge"] = cv
    cv = Canvas(8, 8, RED)
    cv.rect(2, 1, 5, 7, BLK)
    cv.rect(3, 2, 4, 7, RED)
    cv.set(4, 4, BYEL)
    tiles["door"] = cv
    cv = Canvas(8, 8, ORA)
    for x in (0, 3, 6):
        cv.rect(x, 0, x, 7, RED)
    tiles["bridge"] = cv
    cv = snow_tile(8, 0.02)
    cv.rect(0, 2, 7, 6, OLIVE)
    cv.rect(0, 4, 7, 4, BLK)
    cv.rect(3, 2, 3, 3, BLK)
    cv.rect(6, 5, 6, 6, BLK)
    tiles["sandbag"] = cv
    cv = snow_tile(9, 0.03)
    for x, y in ((1, 1), (2, 1), (5, 3), (6, 3), (1, 5), (2, 5), (5, 7), (6, 7)):
        cv.set(x, y, SNOWSH)
    tiles["tracks"] = cv

    # Pine tree, 16x24
    big = Canvas(16, 24, T)
    for layer, (top, half) in enumerate(((1, 2), (6, 4), (11, 6))):
        for dy in range(6):
            w = min(half, 1 + dy)
            for x in range(8 - w, 8 + w):
                big.set(x, top + dy, GRN if (x + dy) % 4 else TEAL)
            big.set(8 - w, top + dy, TEAL)
        for x in range(8 - half, 8 + half, 2):
            big.set(x, top + 5, WHT)       # snow on boughs
    big.rect(7, 17, 8, 20, RED)
    big.outline()
    ground = Canvas(16, 24, WHT)
    random.seed(10)
    for y in range(24):
        for x in range(16):
            if random.random() < 0.04:
                ground.set(x, y, SNOWSH)
    ground.rect(4, 20, 12, 22, SNOWSH)
    ground.paste(big, 0, 0)
    for i in range(6):
        tx, ty = i % 2, i // 2
        cv = Canvas(8, 8)
        cv.paste_from = None
        for y in range(8):
            for x in range(8):
                cv.px[y][x] = ground.px[ty * 8 + y][tx * 8 + x]
        tiles[f"pine{i}"] = cv

    # Radio tower, 16x32
    big = Canvas(16, 32, WHT)
    random.seed(11)
    for y in range(32):
        for x in range(16):
            if random.random() < 0.04:
                big.set(x, y, SNOWSH)
    for y in range(2, 30):
        spread = 1 + (y * 5) // 30
        lx, rx = 7 - spread, 8 + spread
        big.set(lx, y, BLK)
        big.set(rx, y, BLK)
        if y % 4 == 0:
            big.rect(lx, y, rx, y, BRED if (y // 4) % 2 else WHT)
            big.set(lx, y, BLK)
            big.set(rx, y, BLK)
        if y % 4 == 2:
            for x in range(lx + 1, rx):
                if (x - lx) == (rx - x) or abs((x - lx) - (rx - x)) == 1:
                    big.set(x, y, BLK)
    big.rect(7, 0, 8, 1, BRED)
    big.set(7, 0, BYEL)
    big.rect(3, 30, 12, 31, GREY)
    for i in range(8):
        tx, ty = i % 2, i // 2
        cv = Canvas(8, 8)
        for y in range(8):
            for x in range(8):
                cv.px[y][x] = big.px[ty * 8 + y][tx * 8 + x]
        tiles[f"tower{i}"] = cv

    cv = snow_tile(12, 0.05)
    cv.rect(1, 4, 3, 5, GREY)
    cv.rect(4, 5, 6, 6, BLK)
    cv.set(2, 2, BRED)
    cv.set(5, 3, GREY)
    tiles["rubble"] = cv
    cv = Canvas(8, 8, WHT)
    cv.rect(0, 3, 7, 4, BRED)
    for x in (1, 2, 5, 6):
        cv.set(x, 3, WHT)
        cv.set(x - 1 if x < 4 else x + 1, 4, WHT)
    cv.rect(0, 2, 0, 7, BLK)
    tiles["gate"] = cv
    tiles["hud_bg"] = Canvas(8, 8, BBLU)
    cv = Canvas(8, 8, BBLU)
    cv.rect(0, 0, 7, 0, PYEL)
    cv.rect(0, 1, 7, 1, BLUE)
    tiles["hud_edge"] = cv

    return [tiles[n] for n in TILE_NAMES]


# --------------------------------------------------------------------------
# Font (3x5 glyphs in 4x8 cells)
# --------------------------------------------------------------------------

FONT_CHARS = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:!?-/%()',>"
FONT = {
    " ": ["...", "...", "...", "...", "..."],
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
    ".": ["...", "...", "...", "...", ".#."], ":": ["...", ".#.", "...", ".#.", "..."],
    "!": [".#.", ".#.", ".#.", "...", ".#."], "?": ["##.", "..#", ".#.", "...", ".#."],
    "-": ["...", "...", "###", "...", "..."], "/": ["..#", "..#", ".#.", "#..", "#.."],
    "%": ["#.#", "..#", ".#.", "#..", "#.#"], "(": [".#.", "#..", "#..", "#..", ".#."],
    ")": [".#.", "..#", "..#", "..#", ".#."], "'": [".#.", ".#.", "...", "...", "..."],
    ",": ["...", "...", "...", ".#.", "#.."], ">": ["#..", ".#.", "..#", ".#.", "#.."],
}


def font_sheet():
    cells = []
    for ch in FONT_CHARS:
        cv = Canvas(4, 8)
        for y, row in enumerate(FONT[ch]):
            for x, c in enumerate(row):
                if c == "#":
                    cv.set(x, y + 1, PYEL)
        cells.append(cv)
    return cells


# --------------------------------------------------------------------------
# HUD portraits (16x24)
# --------------------------------------------------------------------------

def portrait(hat, uniform, extra=None):
    cv = Canvas(16, 24, BLUE)
    cv.rect(4, 6, 11, 17, SKIN)            # face
    cv.rect(3, 9, 3, 12, SKIN)
    cv.rect(12, 9, 12, 12, SKIN)
    cv.rect(5, 10, 6, 10, BLK)             # eyes
    cv.rect(9, 10, 10, 10, BLK)
    cv.rect(7, 12, 8, 13, RED)             # nose shadow
    cv.rect(6, 15, 9, 15, RED)             # mouth
    cv.rect(2, 19, 13, 23, uniform)        # shoulders
    cv.rect(6, 18, 9, 19, SKIN)
    if hat == "beret":
        cv.rect(3, 3, 11, 6, TEAL)
        cv.rect(10, 4, 12, 7, TEAL)
        cv.set(5, 5, BYEL)
    elif hat == "cap":
        cv.rect(4, 3, 11, 6, BLUE)
        cv.rect(3, 6, 12, 6, BLK)
    elif hat == "hood":
        cv.rect(3, 3, 12, 6, OLIVE)
        cv.rect(3, 7, 3, 16, OLIVE)
        cv.rect(12, 7, 12, 16, OLIVE)
    if extra == "scuba":
        cv.rect(4, 8, 11, 11, SKY)
        cv.rect(4, 8, 11, 8, BLK)
        cv.rect(4, 11, 11, 11, BLK)
    if extra == "scope":
        cv.rect(13, 18, 15, 19, BLK)
    cv.outline()
    return cv


# --------------------------------------------------------------------------
# Title banner for the menu (160x56, full screen width)
# --------------------------------------------------------------------------

def big_text(cv, text, y, sx=2, sy=3, fill=BYEL, shade=ORA, shadow=RED):
    adv = 3 * sx + 1
    x0 = (cv.w - (len(text) * adv - 1)) // 2
    layer = Canvas(cv.w, cv.h)
    for i, ch in enumerate(text):
        for gy, row in enumerate(FONT[ch]):
            for gx, c in enumerate(row):
                if c != "#":
                    continue
                for dy in range(sy):
                    for dx in range(sx):
                        yy = y + gy * sy + dy
                        col = fill if gy * sy + dy < (5 * sy) // 2 else shade
                        layer.set(x0 + i * adv + gx * sx + dx, yy, col)
    drop = Canvas(cv.w, cv.h)
    for yy in range(cv.h):
        for xx in range(cv.w):
            if layer.px[yy][xx] is not T:
                drop.set(xx + 1, yy + 2, shadow)
    drop.paste(layer, 0, 0)
    drop.outline()
    cv.paste(drop, 0, 0)


def title_banner():
    cv = Canvas(160, 56, BLUE)
    random.seed(21)
    for _ in range(40):                                   # stars
        cv.set(random.randrange(160), random.randrange(30), random.choice((WHT, SNOWSH, PYEL)))
    # far mountain range
    peaks = [(0, 34), (18, 22), (34, 30), (52, 16), (70, 28), (88, 18), (108, 30),
             (124, 14), (142, 26), (159, 20)]
    for x in range(160):
        for (x0, y0), (x1, y1) in zip(peaks, peaks[1:]):
            if x0 <= x <= x1:
                top = y0 + (y1 - y0) * (x - x0) // max(1, x1 - x0)
        for y in range(top, 56):
            cv.set(x, y, WHT if y < top + 3 else (GREY if (x + y) % 5 else SNOWSH))
    for y in range(44, 56):                                # snowfield
        for x in range(160):
            cv.set(x, y, SNOWSH if random.random() < 0.15 else WHT)
    big_text(cv, "A HANDFUL", 2)
    big_text(cv, "OF MEN", 21)
    # the squad on the left, a sentry on the right
    beret = person(BERET, "E", 1)
    cv.paste(beret, 6, 40)
    cv.paste(person(BERET, "E", 2), 18, 40)
    cv.paste(person(BERET, "E", 0, "crawl"), 28, 40)
    cv.paste(mirror(person(GUARD, "E", 0)), 140, 40)
    return cv


def write_manifest(folder, sheets):
    with open(os.path.join(ASSETS, folder, "manifest.json"), "w") as f:
        json.dump({"sheets": sheets}, f, indent=2)
        f.write("\n")


def main():
    save_sheet(sprite_sheet(BERET), os.path.join(ASSETS, "sprites", "beret.png"))
    save_sheet(sprite_sheet(GUARD), os.path.join(ASSETS, "sprites", "guard.png"))
    save_sheet(cursor_sheet(), os.path.join(ASSETS, "sprites", "cursor.png"))
    write_manifest("sprites", [
        {"file": "beret.png", "label": "spr_beret", "cell": [12, 16], "kind": "masked"},
        {"file": "guard.png", "label": "spr_guard", "cell": [12, 16], "kind": "masked"},
        {"file": "cursor.png", "label": "spr_cursor", "cell": [8, 8], "kind": "masked"},
    ])
    save_sheet(make_tiles(), os.path.join(ASSETS, "tiles", "norway.png"), cols=8)
    write_manifest("tiles", [
        {"file": "norway.png", "label": "tiles", "cell": [8, 8], "kind": "plain",
         "count": len(TILE_NAMES)},
    ])
    save_sheet(font_sheet(), os.path.join(ASSETS, "ui", "font.png"), cols=16)
    save_sheet([title_banner()], os.path.join(ASSETS, "ui", "title.png"))
    save_sheet([portrait("beret", GRN), portrait("cap", BLUE, "scuba"), portrait("hood", OLIVE, "scope")],
               os.path.join(ASSETS, "ui", "portraits.png"))
    write_manifest("ui", [
        {"file": "font.png", "label": "font", "cell": [4, 8], "kind": "font",
         "count": len(FONT_CHARS)},
        {"file": "portraits.png", "label": "portrait", "cell": [16, 24], "kind": "plain"},
        {"file": "title.png", "label": "title_gfx", "cell": [160, 56], "kind": "plain"},
    ])
    with open(os.path.join(ASSETS, "ui", "font_chars.txt"), "w") as f:
        f.write(FONT_CHARS + "\n")
    print("gen_art: sheets written to assets/")


if __name__ == "__main__":
    main()
