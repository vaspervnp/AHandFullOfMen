#!/usr/bin/env python3
"""Bubble-letter title logo -> Aseprite (assets/aseprite/logo.aseprite).

Usage: logo_gen.py <out.lua>   (then run the Lua with Aseprite, see below)

Each letter is a 5x7 grid; neighbouring cells are joined into a skeleton,
which is inflated with an elliptical brush (Mode 0 pixels are twice as wide
as tall) into round, chubby strokes. Pink fill with a white shine, a white
rim, a dark red outline and a drop shadow (rims outside only, so the holes
in A, O, D stay open); letters bob up and down. The
result is exact 160x56 pixel art for the title banner.

  aseprite -b --script-param pal=<terrain.aseprite> \\
      --script-param ase=<logo.aseprite> --script <out.lua>
"""
import sys

G = {
    'A': ".###. #...# #...# ##### #...# #...# #...#",
    'H': "#...# #...# #...# ##### #...# #...# #...#",
    'N': "#...# ##..# #.#.# #..## #...# #...# #...#",
    'D': "####. #...# #...# #...# #...# #...# ####.",
    'F': "##### #.... #.... ####. #.... #.... #....",
    'U': "#...# #...# #...# #...# #...# #...# .###.",
    'L': "#.... #.... #.... #.... #.... #.... #####",
    'O': ".###. #...# #...# #...# #...# #...# .###.",
    'M': "#...# ##.## #.#.# #.#.# #...# #...# #...#",
    'E': "##### #.... #.... ####. #.... #.... #####",
}
W, H = 160, 56
SX, SY = 2.3, 2.75                  # grid step: Mode 0 pixels across, rows down
RX, RY = 1.35, 1.9                  # brush radii
ADV, GAP, SPACE = 13, 1, 5          # letter advance, extra gap, word space
FILL, SHINE, RIM, EDGE, SHADOW = 10, 1, 1, 8, 0
LINES = (("A HANDFUL", 4), ("OF MEN", 30))
SPARKLES = ((8, 8), (150, 20), (14, 40), (146, 47))


def skeleton(ch):
    rows = G[ch].split()
    on = {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == '#'}
    segs = []
    for (x, y) in on:
        for dx, dy in ((1, 0), (0, 1)):
            if (x + dx, y + dy) in on:
                segs.append(((x, y), (x + dx, y + dy)))
        for dx in (1, -1):                       # diagonals where no corner joins them
            if (x + dx, y + 1) in on and (x + dx, y) not in on and (x, y + 1) not in on:
                segs.append(((x, y), (x + dx, y + 1)))
    return on, segs


def main():
    px = [[None] * W for _ in range(H)]
    ink = [[0.0] * W for _ in range(H)]          # 0..1: how far inside the stroke
    for text, top in LINES:
        width = sum(SPACE if c == ' ' else ADV + GAP for c in text) - GAP
        x0 = (W - width) // 2
        k = 0
        for ch in text:
            if ch == ' ':
                x0 += SPACE
                continue
            bob = -1 if k % 2 else 1             # letters bob up and down
            k += 1
            on, segs = skeleton(ch)
            pts = [(x, y) for x, y in on]
            for (a, b) in segs:
                for t in range(1, 8):
                    pts.append((a[0] + (b[0] - a[0]) * t / 8, a[1] + (b[1] - a[1]) * t / 8))
            ox, oy = x0 + RX + 0.5, top + RY + bob
            for gx, gy in pts:
                cx, cy = ox + gx * SX, oy + gy * SY
                for y in range(int(cy - RY) - 1, int(cy + RY) + 2):
                    for x in range(int(cx - RX) - 1, int(cx + RX) + 2):
                        if 0 <= x < W and 0 <= y < H:
                            d = ((x + 0.5 - cx) / RX) ** 2 + ((y + 0.5 - cy) / RY) ** 2
                            if d <= 1.0:
                                ink[y][x] = max(ink[y][x], 1 - d)
                                px[y][x] = FILL
            # shine: the top-left of the letter's first stroke
            sx, sy = min(on, key=lambda p: (p[1], p[0]))
            hx, hy = int(ox + sx * SX - 0.5), int(oy + sy * SY - 1)
            for x, y in ((hx, hy), (hx, hy + 1)):
                if 0 <= x < W and 0 <= y < H and px[y][x] == FILL:
                    px[y][x] = SHINE
            x0 += ADV + GAP

    def flood():                                 # empty pixels reachable from the frame
        seen, todo = set(), [(x, y) for x in range(W) for y in (0, H - 1)]
        while todo:
            x, y = todo.pop()
            if (x, y) in seen or not (0 <= x < W and 0 <= y < H) or px[y][x] is not None:
                continue
            seen.add((x, y))
            todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        return seen

    def ring(colour, inside, only=None):
        add = [(x, y) for y in range(H) for x in range(W) if px[y][x] is None
               and (only is None or (x, y) in only) and any(
            0 <= x + dx < W and 0 <= y + dy < H and px[y + dy][x + dx] in inside
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in add:
            px[y][x] = colour
    ring(RIM, (FILL, SHINE), only=flood())      # rims outside only: counters stay open
    ring(EDGE, (FILL, SHINE, RIM), only=flood())
    outside = flood()                            # drop shadow below, outside only
    for x, y in [(x, y + 1) for y in range(H - 1) for x in range(W)
                 if px[y][x] == EDGE and (x, y + 1) in outside]:
        px[y][x] = SHADOW
    for sx, sy in SPARKLES:                      # little white stars
        for x, y in ((sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)):
            if px[y][x] is None:
                px[y][x] = SHINE
    assert all(px[y][x] is None for y in (0, H - 1) for x in range(W)), "logo touches the frame"
    lua = ['local pal = app.open(app.params["pal"]).palettes[1]',
           f'local spr = Sprite({W}, {H}, ColorMode.INDEXED)',
           'spr:setPalette(pal)', 'spr.transparentColor = 16',
           f'local im = Image({W}, {H}, ColorMode.INDEXED)', 'im:clear(16)']
    lua += [f'im:drawPixel({x},{y},{px[y][x]})' for y in range(H) for x in range(W) if px[y][x] is not None]
    lua += ['spr.cels[1].image = im', 'spr:saveAs(app.params["ase"])', 'print("logo", spr.width, spr.height)']
    open(sys.argv[1], "w").write('\n'.join(lua))
    for y in range(H):
        print(''.join('.' if p is None else {FILL: '#', 1: 'w', EDGE: 'r', SHADOW: 'k'}[p] for p in px[y]))


if __name__ == "__main__":
    main()
