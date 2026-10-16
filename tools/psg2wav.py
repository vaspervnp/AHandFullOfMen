#!/usr/bin/env python3
"""Record what the AY plays in a snapshot and render it to a WAV file.

Usage: psg2wav.py game.sna out.wav [--frames N] [--keys SCRIPT] [--notes]
Runs the snapshot in tools/cpcsim.py, samples the AY registers once per
frame (50 Hz) and synthesises channels A-C as square waves (tone only,
volume from registers 8-10; noise is approximated with random samples).
--notes prints the note each tone channel starts, frame by frame.
"""
import argparse
import math
import os
import random
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpcsim  # noqa: E402

RATE = 22050
AY_CLOCK = 1_000_000
NAMES = ["c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b"]


def note_name(period):
    if not period:
        return "-"
    f = AY_CLOCK / (16 * period)
    m = round(69 + 12 * math.log2(f / 440))
    return f"{NAMES[m % 12]}{m // 12 - 1}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sna")
    ap.add_argument("wav")
    ap.add_argument("--frames", type=int, default=1500)
    ap.add_argument("--keys")
    ap.add_argument("--notes", action="store_true")
    a = ap.parse_args()
    cpc = cpcsim.CPC(a.sna)
    cpc.psg_log = []
    script = cpcsim.parse_keys(a.keys)
    for f in range(a.frames):
        cpc.keys_down = {k for (s, e, ks) in script if s <= f <= e for k in ks}
        cpc.run_frame()
    log = cpc.psg_log
    out = bytearray()
    phase = [0.0, 0.0, 0.0]
    per_frame = RATE // 50
    last = [None, None, None]
    for f, r in enumerate(log):
        mixer = r[7]
        for ch in range(3):
            p = r[ch * 2] | (r[ch * 2 + 1] & 15) << 8
            vol = r[8 + ch] & 15
            on = not mixer & (1 << ch) and vol and p
            key = (p, vol > 0) if on else None
            if a.notes and on and (last[ch] is None or last[ch][0] != p or
                                   (r[8 + ch] & 15) > (log[f - 1][8 + ch] & 15 if f else 0)):
                print(f"frame {f:5d} ch {'ABC'[ch]} {note_name(p)}")
            last[ch] = key
        for _ in range(per_frame):
            s = 0.0
            for ch in range(3):
                p = r[ch * 2] | (r[ch * 2 + 1] & 15) << 8
                vol = r[8 + ch] & 15
                if not vol:
                    continue
                amp = vol / 15 / 3
                if not mixer & (1 << ch) and p:
                    phase[ch] = (phase[ch] + AY_CLOCK / (16 * p) / RATE) % 1.0
                    s += amp if phase[ch] < 0.5 else -amp
                elif not mixer & (8 << ch):
                    s += amp * random.uniform(-1, 1)
            out += struct.pack("<h", int(max(-1, min(1, s)) * 20000))
    with wave.open(a.wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(out))
    print(f"psg2wav: {len(log)} frames -> {a.wav}")


if __name__ == "__main__":
    main()
