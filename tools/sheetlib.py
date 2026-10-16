"""Shared helpers for the art tools: pen names, a tiny pixel canvas, sheet
writing. Pens are indices into the game palette (tools/cpcpal.py)."""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpcpal import GAME_RGB, TRANSPARENT  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(ROOT, "assets")

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


def mirror(cv):
    out = Canvas(cv.w, cv.h)
    for y in range(cv.h):
        out.px[y] = cv.px[y][::-1]
    return out


def from_png(path):
    """Load a palette-exact PNG (alpha or #FF00FF = transparent) as a Canvas."""
    img = Image.open(path).convert("RGBA")
    rgb2pen = {rgb: i for i, rgb in enumerate(GAME_RGB)}
    cv = Canvas(img.width, img.height)
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a >= 128 and (r, g, b) != TRANSPARENT:
                cv.px[y][x] = rgb2pen[(r, g, b)]
    return cv


def crop(cv, x0, y0, w, h):
    out = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            out.px[y][x] = cv.get(x0 + x, y0 + y)
    return out
