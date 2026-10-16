#!/usr/bin/env python3
"""Soak test: random play in the simulator, looking for crashes and hangs.

Usage: tests/fuzz.py [--seeds 1-8] [--ticks 3000]
Assembles tests/fuzz.asm with -DFUZZ=1 -DFUZZ_SEED=n (random stick, fire and
command keys, ESC included; game over and the menu are played through) and
runs each seed in tools/cpcsim.py. Fails if, at any 64 T-state sample, PC
leaves the code (or the IM 1 vector) or SP leaves the stack; if the input
stops being consumed for 400 frames (hang); if the program reaches &0000
before the random input runs out; or if the stack canary or the entity
table is damaged at the end. Prints frames-per-tick and missions per seed.
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cpcsim  # noqa: E402

ENT_SIZE, MAX_ENTS = 32, 16
ET_MAX = 7                       # highest entity type (ET_BOMB) in src/defs.asm


def build(seed, ticks):
    os.makedirs(os.path.join(ROOT, "build", "tests"), exist_ok=True)
    out = f"tests/fuzz_{seed}"
    r = subprocess.run(["rasm", "-amper", "-v2", "-I../src", "-I.", "-DFUZZ=1",
                        f"-DFUZZ_SEED={seed}", f"-DFUZZ_TICKS={ticks}", "../tests/fuzz.asm",
                        "-oi", out + ".sna", "-os", out + ".sym", "-s", "-sl"],
                       cwd=os.path.join(ROOT, "build"), capture_output=True, text=True)
    if r.returncode or "error" in r.stdout.lower():
        sys.exit(f"fuzz: assembly failed\n{r.stdout[-2000:]}")
    return os.path.join(ROOT, "build", out)


def run(base, slow, ticks):
    cpc = cpcsim.CPC(base + ".sna")
    cpc.slow = slow
    syms = cpcsim.load_syms(base + ".sym")
    code_hi = syms["vars_start"]
    m = cpc.m
    bad = []
    orig = m.run
    armed = [False]                 # SP is checked once the game has set it

    def hook():
        pc, sp = m.pc, m.sp
        in_stack = 0x3F00 <= sp <= 0x4000
        armed[0] = armed[0] or in_stack
        if not (pc == 0 or 0x38 <= pc < 0x3C or 0x40 <= pc < code_hi) or (armed[0] and not in_stack):
            bad.append((cpc.frame, pc, sp))
            cpc.stopped = True
        return orig()
    m.run = hook
    count = syms["fuzz_count"]
    last, still, missions, prev_tick = None, 0, 0, 0
    limit = ticks * 6 + 2000
    while not cpc.stopped and cpc.frame < limit:
        cpc.run_frame()
        left = cpc.base_ram(count, 2)
        left = left[0] | left[1] << 8
        still = still + 1 if left == last else 0
        last = left
        if still > 400:
            return f"hang at frame {cpc.frame} (PC={m.pc:04X})", cpc, syms, missions
        tick = cpc.base_ram(syms["tick"])[0]
        if tick < prev_tick and prev_tick > 5:
            missions += 1
        prev_tick = tick
    if bad:
        f, pc, sp = bad[0]
        return f"wild PC={pc:04X} SP={sp:04X} at frame {f}", cpc, syms, missions
    if not cpc.stopped:
        return "never finished", cpc, syms, missions
    if last:
        return f"reached &0000 with {last} input steps left (crash?)", cpc, syms, missions
    if any(b != 0xA5 for b in cpc.base_ram(0x3F00, 128)):
        return "stack canary damaged", cpc, syms, missions
    ents = cpc.base_ram(syms["ent_table"], ENT_SIZE * MAX_ENTS)
    for i in range(MAX_ENTS):
        t, x = ents[i * ENT_SIZE], ents[i * ENT_SIZE + 1]
        if t > ET_MAX or (t and x >= 160):
            return f"entity {i} corrupt (type {t}, x {x})", cpc, syms, missions
    return None, cpc, syms, missions


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", default="1-8")
    ap.add_argument("--ticks", type=int, default=3000)
    ap.add_argument("--slow", type=float, default=1.25)
    a = ap.parse_args()
    lo, _, hi = a.seeds.partition("-")
    seeds = range(int(lo), int(hi or lo) + 1)
    fail = 0
    for seed in seeds:
        err, cpc, syms, missions = run(build(seed, a.ticks), a.slow, a.ticks)
        hist = list(cpc.base_ram(syms["frame_hist"], 8))
        ticks = " ".join(f"{n}f:{hist[n]}" for n in range(1, 8) if hist[n])
        state = f"{cpc.frame} frames, {missions + 1} missions, ticks {ticks}"
        if err:
            print(f"FAIL fuzz seed {seed}: {err} ({state})")
            fail = 1
        else:
            print(f"ok   fuzz seed {seed}: {state}")
    sys.exit(fail)


if __name__ == "__main__":
    main()
