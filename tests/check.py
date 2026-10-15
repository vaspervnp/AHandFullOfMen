#!/usr/bin/env python3
"""Per-scenario assertions, run against tools/cpcsim.py.

Usage: check.py <test name>   (expects build/tests/<name>.sna/.sym)
Each scenario's script ends with a jump to &0000; we then inspect RAM.
"""
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cpcsim  # noqa: E402

ENT_SIZE = 32
ENT = {"type": 0, "x": 1, "y": 2, "dir": 3, "state": 5, "tx": 6, "ty": 7, "flags": 8,
       "hp": 14, "ai": 16}
EF_CRAWL, EF_DEAD = 1, 4


class Run:
    def __init__(self, name, max_frames=3000):
        base = os.path.join(ROOT, "build", "tests", name)
        self.cpc = cpcsim.CPC(base + ".sna")
        self.syms = cpcsim.load_syms(base + ".sym")
        for _ in range(max_frames):
            self.cpc.run_frame()
            if self.cpc.stopped:
                break
        self.cpc.screen_png(base + "_sim.png")

    def byte(self, name, off=0):
        return self.cpc.base_ram(self.syms[name.lower()] + off)[0]

    def ent(self, i, field):
        return self.byte("ent_table", i * ENT_SIZE + ENT[field])


def check_t01_boot(r):
    assert r.byte("game_over") == 0, "game over at boot"
    assert r.byte("tick") >= 40, f"only {r.byte('tick')} ticks ran"
    assert r.ent(0, "type") == 1 and r.ent(3, "type") == 2, "entities not spawned"
    # both buffers must be fully drawn once the view is clean
    assert r.byte("view_dirty") == 0, "view never finished drawing"
    # HUD panel colour present at the bottom of the displayed screen
    scr = r.cpc.base_ram(((r.cpc.crtc[12] >> 4) & 3) * 0x4000 + 7 * 0x800 + 23 * 80, 80)
    assert any(b != 0 for b in scr), "HUD row is blank"


def check_t02_move(r):
    x, y = r.ent(0, "x"), r.ent(0, "y")
    assert (x, y) != (18, 239), "Green Beret did not move"
    assert y < 239, f"Green Beret should have walked north, y={y}"


def check_t03_knife(r):
    assert r.ent(3, "flags") & EF_DEAD, "guard survived the knife"
    assert r.byte("alarm") == 0, "a silent kill must not raise the alarm"


def check_t04_spotted(r):
    assert r.byte("alarm") == 1, "standing commando in the cone was not spotted"
    assert r.ent(3, "ai") == 3, f"guard AI state {r.ent(3, 'ai')}, expected ALARM"


def check_t05_crawl_hidden(r):
    assert r.byte("alarm") == 0, "crawling commando in the long zone was spotted"
    assert r.ent(3, "ai") == 0, f"guard AI state {r.ent(3, 'ai')}, expected PATROL"


def check_t06_menu(r):
    assert r.ent(0, "type") == 1, "mission did not start from the menu"
    assert r.byte("view_dirty") == 0, "mission view not drawn after the menu"


def check_t07_menu_screen(r):
    assert r.cpc.crtc[12] == 0x30, "menu should be on the &C000 screen"
    # banner present (top line not plain background), text rows drawn
    top = r.cpc.base_ram(0xC000, 80)
    assert len(set(top)) > 2, "title banner missing"


def check_t08_cone(r):
    assert r.byte("cone_guard") == 3, f"cone_guard={r.byte('cone_guard')}"
    n = r.byte("cone_count")
    assert 20 < n <= 9 * 16, f"cone has {n} dots"


def check_t09_footsteps(r):
    assert r.ent(3, "ai") != 0, "sentry did not react to footsteps on snow"


def check_t10_decoy(r):
    assert r.ent(3, "ai") == 1, f"guard AI {r.ent(3, 'ai')}, expected INVESTIGATE"
    x, y = r.ent(3, "x"), r.ent(3, "y")
    assert abs(x - 50) <= 2 and abs(y - 170) <= 2, f"guard at {x},{y}, decoy at 50,170"


CHECKS = {k[len("check_"):]: v for k, v in globals().items() if k.startswith("check_")}


def main():
    name = sys.argv[1]
    r = Run(name)
    if not r.cpc.stopped:
        print(f"FAIL {name}: script never finished (crash or hang?) PC={r.cpc.m.pc:04X}")
        sys.exit(1)
    check = CHECKS.get(name)
    if check:
        try:
            check(r)
        except AssertionError as e:
            print(f"FAIL {name}: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()
