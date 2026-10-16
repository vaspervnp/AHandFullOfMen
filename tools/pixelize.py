"""Turn flat-shaded Blender renders into Mode 0 pixel art.

Renders come out of Workbench as exact palette colours, oversampled by
(bw, bh) per Mode 0 pixel (8x4 by default: 2:1 pixels at 4 render pixels
per scanline). Each block becomes the most common opaque colour in it if
enough of the block is covered, so edges stay crisp and thin details
(rifles, aerials) survive instead of being averaged away.
"""
import collections
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpcpal import GAME_RGB  # noqa: E402

T = None


def nearest_pen(rgb):
    return min(range(16), key=lambda i: sum((a - b) ** 2 for a, b in zip(rgb, GAME_RGB[i])))


def pixelize(path, bw=8, bh=4, cover=6, priority=()):
    """-> rows of pen numbers / None. `priority` pens win a block whenever
    they reach `cover` pixels (keeps faces and gun barrels visible)."""
    img = Image.open(path).convert("RGBA")
    w, h = img.width // bw, img.height // bh
    px = img.load()
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            counts = collections.Counter()
            for dy in range(bh):
                for dx in range(bw):
                    r, g, b, a = px[x * bw + dx, y * bh + dy]
                    if a >= 128:
                        counts[(r, g, b)] += 1
            opaque = sum(counts.values())
            if opaque < cover:
                row.append(T)
                continue
            pens = collections.Counter()
            for rgb, n in counts.items():
                pens[nearest_pen(rgb)] += n
            pick = None
            for p in priority:
                if pens.get(p, 0) >= cover:
                    pick = p
                    break
            row.append(pick if pick is not None else pens.most_common(1)[0][0])
        out.append(row)
    return out
