#!/usr/bin/env python3
"""Frame budget report: frames per game tick for every test scenario.

Usage: tests/frames.py [--cap32] [--slow F] [--max N] [names...]
Prints the histogram the TEST build records in frame_hist (ticks that took
1..7 frames). By default it runs build/tests/<name>.sna in cpcsim with
T-states scaled by F; with --cap32 the numbers come from Caprice32, which
times the CPC exactly: at the end of the script the TEST build copies a
marker + frame_hist onto line 0 of the screen and we decode the screenshot.
With --max, exits 1 if any tick took more than N frames.
"""
import argparse
import glob
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cpcsim  # noqa: E402
from cpcpal import GAME_RGB, mode0_byte  # noqa: E402


def run(name, slow, max_frames=3000):
    base = os.path.join(ROOT, "build", "tests", name)
    cpc = cpcsim.CPC(base + ".sna")
    cpc.slow = slow
    syms = cpcsim.load_syms(base + ".sym")
    for _ in range(max_frames):
        cpc.run_frame()
        if cpc.stopped:
            break
    return list(cpc.base_ram(syms["frame_hist"], 8)), cpc.stopped


def run_cap32(name):
    from PIL import Image
    base = os.path.join(ROOT, "build", "tests", name)
    shot = base + "_frames.png"
    r = subprocess.run([os.path.join(ROOT, "tools", "cpcemu"), "-timeout", "90", "-shot", shot,
                        base + ".sna"], capture_output=True)
    if r.returncode:
        return [0] * 8, False
    im = Image.open(shot).convert("RGB")
    x0, y0 = 64, 82                    # 640x400 picture inside the border
    if im.size != (768, 540):
        raise SystemExit(f"unexpected Caprice32 screenshot size {im.size}")

    def pen(i):
        c = im.getpixel((x0 + 4 * i + 2, y0 + 1))
        return min(range(16), key=lambda p: sum((a - b) ** 2 for a, b in zip(c, GAME_RGB[p])))
    data = [mode0_byte(pen(2 * i), pen(2 * i + 1)) for i in range(10)]
    if data[:2] != [0xAA, 0x55]:
        raise SystemExit(f"{name}: frame_hist marker not found on screen")
    return data[2:], True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slow", type=float, default=1.25)
    ap.add_argument("--max", type=int, default=0)
    ap.add_argument("--cap32", action="store_true")
    ap.add_argument("names", nargs="*")
    a = ap.parse_args()
    names = a.names or sorted(n for n in (os.path.basename(p)[:-4] for p in glob.glob(
        os.path.join(ROOT, "build", "tests", "t[0-9][0-9]_*.sna"))) if not n.endswith("_ref"))
    bad = 0
    total = [0] * 8
    src = "Caprice32" if a.cap32 else f"cpcsim x{a.slow}"
    print(f"frames/tick ({src}):".ljust(25) + " ".join(f"{n:>4}" for n in range(1, 8)) + "   worst")
    for name in names:
        hist, ok = run_cap32(name) if a.cap32 else run(name, a.slow)
        total = [t + h for t, h in zip(total, hist)]
        worst = max((n for n in range(8) if hist[n]), default=0)
        flag = ""
        if not ok:
            flag = "  (did not finish)"
            bad = 1
        if a.max and worst > a.max:
            flag += f"  OVER BUDGET"
            bad = 1
        print(f"  {name:22s} " + " ".join(f"{hist[n]:4d}" for n in range(1, 8)) + f"   {worst}{flag}")
    print(f"  {'total':22s} " + " ".join(f"{total[n]:4d}" for n in range(1, 8)))
    sys.exit(bad)


if __name__ == "__main__":
    main()
