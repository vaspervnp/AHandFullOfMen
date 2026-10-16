#!/usr/bin/env python3
"""Per-scenario assertions, run against tools/cpcsim.py.

Usage: check.py <test name>   (expects build/tests/<name>.sna/.sym)
Each scenario's script ends with a jump to &0000; we then inspect RAM.
If build/tests/<name>_ref.sna exists (the same scenario assembled with
REF_RENDER=1, which redraws the whole view every frame), the screen shown
at the end must match it byte for byte: the dirty-tile renderer may skip
work, never pixels.
"""
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cpcsim  # noqa: E402

ENT_SIZE = 32
ENT = {"type": 0, "x": 1, "y": 2, "dir": 3, "state": 5, "tx": 6, "ty": 7, "flags": 8,
       "hp": 14, "ai": 16, "drag": 21}
EF_CRAWL, EF_DEAD, EF_BOARDED = 1, 4, 16


class Run:
    def __init__(self, name, max_frames=3000, png=True):
        base = os.path.join(ROOT, "build", "tests", name)
        self.cpc = cpcsim.CPC(base + ".sna")
        self.syms = cpcsim.load_syms(base + ".sym")
        for _ in range(max_frames):
            self.cpc.run_frame()
            if self.cpc.stopped:
                break
        if png:
            self.cpc.screen_png(base + "_sim.png")

    def shown(self):
        """Displayed screen, minus the frame_hist bytes test_end puts on line 0."""
        scr = self.cpc.base_ram(((self.cpc.crtc[12] >> 4) & 3) * 0x4000, 0x4000)
        scr[0:10] = bytes(10)
        return scr

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
    assert r.byte("mus_on") == 1, "no title music"
    assert r.cpc.crtc[12] == 0x30, "menu should be on the &C000 screen"
    # banner present: a line through the logo is not plain background
    line = r.cpc.base_ram(0xC000 + (20 % 8) * 0x800 + (20 // 8) * 80, 80)
    assert len(set(line)) > 3, "title banner missing"


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


def check_t11_tower(r):
    assert r.byte("tower_down") == 1, "radio tower still standing"
    assert r.byte("alarm") == 1, "an explosion must raise the alarm"
    assert r.ent(8, "type") == 0, "barrel should be gone"
    assert r.byte("ammo") == 4, f"ammo {r.byte('ammo')}, expected 4"
    assert not r.ent(2, "flags") & EF_DEAD, "the Sniper was caught in his own blast"


def check_t12_drag(r):
    assert r.ent(0, "drag") == 10, f"drag={r.ent(0, 'drag')}, expected barrel 9+1"
    assert r.ent(9, "x") < 60, f"barrel x={r.ent(9, 'x')}, should have moved west"


def check_t13_escape(r):
    assert r.ent(0, "flags") & EF_BOARDED, "Green Beret did not board the truck"
    assert r.byte("game_over") == 2, f"game_over={r.byte('game_over')}, expected 2"
    assert r.byte("end_reason") == 2


def check_t14_harpoon(r):
    assert r.ent(3, "flags") & EF_DEAD, "harpoon missed"
    assert r.byte("alarm") == 0, "harpoon must be silent"


def check_t15_reinforced(r):
    assert r.byte("game_over") == 1 and r.byte("end_reason") == 1, \
        f"game_over={r.byte('game_over')} reason={r.byte('end_reason')}"


def check_t16_debrief(r):
    assert r.cpc.crtc[12] == 0x30, "debrief should be on the &C000 screen"
    assert r.byte("game_over") == 2
    assert r.byte("mus_on") == 1, "no music on the debrief"
    ptr = r.byte("mus_voices") | r.byte("mus_voices", 1) << 8
    lo, hi = r.syms["song_win_a"], r.syms["song_win_b"]
    assert lo <= ptr <= hi, f"voice A at {ptr:04X}, not in the victory fanfare {lo:04X}-{hi:04X}"


def near(r, i, x, y, tol_x=2, tol_y=4):
    ex, ey = r.ent(i, "x"), r.ent(i, "y")
    return abs(ex - x) <= tol_x and abs(ey - y) <= tol_y, (ex, ey)


def check_t17_path_tree(r):
    ok, pos = near(r, 0, 40, 172)
    assert ok, f"Green Beret at {pos}, should have walked round the pine to (40,172)"


def check_t18_river_detour(r):
    ok, pos = near(r, 0, 60, 119)
    assert ok, f"Green Beret at {pos}, should have detoured to (60,119)"


def check_t19_marine_swim(r):
    ok, pos = near(r, 1, 60, 119)
    assert ok, f"Marine at {pos}, should have swum straight to (60,119)"


def check_t20_unreachable(r):
    assert (r.ent(0, "x"), r.ent(0, "y")) == (18, 239), "walked toward an unreachable spot"
    assert r.ent(0, "state") == 0, "should have refused the order"


def check_t21_cone_patrol(r):
    assert r.byte("cone_pinned") == 7, f"cone_pinned={r.byte('cone_pinned')}"
    assert r.byte("cone_count") > 20, f"cone has {r.byte('cone_count')} dots"
    assert r.ent(7, "x") > 30, f"river guard at x={r.ent(7, 'x')}, should be patrolling east"


CHECKS = {k[len("check_"):]: v for k, v in globals().items() if k.startswith("check_")}


def main():
    name = sys.argv[1]
    r = Run(name)
    if not r.cpc.stopped:
        print(f"FAIL {name}: script never finished (crash or hang?) PC={r.cpc.m.pc:04X}")
        sys.exit(1)
    canary = r.cpc.base_ram(0x3F00, 128)
    if any(b != 0xA5 for b in canary):
        print(f"FAIL {name}: the stack grew into the canary at &3F00 (STACK_RESERVE)")
        sys.exit(1)
    check = CHECKS.get(name)
    if check:
        try:
            check(r)
        except AssertionError as e:
            print(f"FAIL {name}: {e}")
            sys.exit(1)
    if os.path.exists(os.path.join(ROOT, "build", "tests", name + "_ref.sna")):
        ref = Run(name + "_ref", png=False)
        a, b = r.shown(), ref.shown()
        if a != b:
            bad = [i for i in range(0x4000) if a[i] != b[i]]
            lines = sorted({(i % 0x800) // 80 * 8 + i // 0x800 for i in bad if i % 0x800 < 2000})
            print(f"FAIL {name}: screen differs from the full-redraw reference in {len(bad)} "
                  f"bytes, lines {lines[:12]}{'...' if len(lines) > 12 else ''}")
            sys.exit(1)


if __name__ == "__main__":
    main()
