#!/usr/bin/env python3
"""Inclusive per-routine time for a test scenario, at CPC timing.

Usage: tools/profile_calls.py <test name> [--from F] [--to F] [--slow 1.25]
Samples the simulator (tools/cpcsim.py) every 64 T-states; for each sample
it credits the routine at PC and the target of every CALL whose return
address is on the stack, so a routine's share includes its callees (a
jp-tail-call is credited to the routine that was called). Prints frames of CPU time per call-tree node over the window.
"""
import argparse
import bisect
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpcsim  # noqa: E402

CALLS = {0xCD, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--from", dest="f0", type=int, default=0)
    ap.add_argument("--to", dest="f1", type=int, default=3000)
    ap.add_argument("--slow", type=float, default=1.25)
    ap.add_argument("--top", type=int, default=30)
    a = ap.parse_args()
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "tests", a.name)
    cpc = cpcsim.CPC(base + ".sna")
    cpc.slow = a.slow
    syms = cpcsim.load_syms(base + ".sym")
    top = sorted((v, k) for k, v in syms.items() if "." not in k and v < 0x4000)
    keys = [t[0] for t in top]

    def name(pc):
        i = bisect.bisect_right(keys, pc) - 1
        return top[i][1] if i >= 0 else "?"
    incl = collections.Counter()
    m = cpc.m
    n = 0
    while not cpc.stopped and cpc.frame < a.f1:
        if cpc.frame < a.f0:
            cpc.run_frame()
            continue
        cpc.samples = []
        sps = []
        orig = m.run

        def run_hook():
            sps.append((m.pc, m.sp))
            return orig()
        m.run = run_hook
        cpc.run_frame()
        m.run = orig
        mem = m.memory
        for pc, sp in sps:
            seen = {name(pc)}
            for s in range(sp, 0x4000 - 1, 2):
                ra = mem[s] | mem[s + 1] << 8
                if 0x43 <= ra < 0x4000 and mem[ra - 3] in CALLS:
                    seen.add(name(mem[ra - 2] | mem[ra - 1] << 8))   # the callee
            for k in seen:
                incl[k] += 1
            n += 1
    frames = cpc.frame - a.f0
    print(f"{n} samples over {frames} frames (inclusive time, in frames per frame of run)")
    for k, v in incl.most_common(a.top):
        print(f"  {v / n * 100:5.1f}%  {k}")


if __name__ == "__main__":
    main()
