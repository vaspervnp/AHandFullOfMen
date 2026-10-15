#!/usr/bin/env python3
"""Inspect a CPC .sna snapshot (v1-v3, uncompressed or MEM chunks).

Usage:
    snapinfo.py file.sna [--sym file.sym] [--peek ADDR[:LEN] ...] [--screen out.png]

Prints CPU registers, Gate Array and CRTC state; --peek dumps base-RAM bytes
(addresses or symbol names); --screen decodes the displayed screen as a
Mode 0 image using the snapshot's palette.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpcpal import HW_TO_RGB, mode0_unpack  # noqa: E402

HW_INDEX = {0x54: 0x14, 0x44: 0x04, 0x55: 0x15, 0x5C: 0x1C, 0x58: 0x18, 0x5D: 0x1D, 0x4C: 0x0C,
            0x45: 0x05, 0x4D: 0x0D, 0x56: 0x16, 0x46: 0x06, 0x57: 0x17, 0x5E: 0x1E, 0x40: 0x00,
            0x5F: 0x1F, 0x4E: 0x0E, 0x47: 0x07, 0x4F: 0x0F, 0x52: 0x12, 0x42: 0x02, 0x53: 0x13,
            0x5A: 0x1A, 0x59: 0x19, 0x5B: 0x1B, 0x4A: 0x0A, 0x43: 0x03, 0x4B: 0x0B}
IDX_TO_RGB = {idx: HW_TO_RGB[hw] for hw, idx in HW_INDEX.items()}


def load(path):
    d = open(path, "rb").read()
    assert d[:8] == b"MV - SNA", "not a snapshot"
    hdr = d[:0x100]
    size = hdr[0x6B] | hdr[0x6C] << 8
    mem = bytearray(d[0x100:0x100 + size * 1024])
    # v3 chunks (MEM0..MEM8, possibly RLE-compressed)
    pos = 0x100 + size * 1024
    while pos + 8 <= len(d):
        name, ln = d[pos:pos + 4], int.from_bytes(d[pos + 4:pos + 8], "little")
        body = d[pos + 8:pos + 8 + ln]
        if name[:3] == b"MEM":
            bank = name[3] - 0x30
            raw = rle(body) if ln != 0x10000 else body
            need = (bank + 1) * 0x10000
            if len(mem) < need:
                mem.extend(bytes(need - len(mem)))
            mem[bank * 0x10000:bank * 0x10000 + 0x10000] = raw[:0x10000]
        pos += 8 + ln
    return hdr, mem


def rle(b):
    out = bytearray()
    i = 0
    while i < len(b):
        if b[i] == 0xE5:
            n = b[i + 1]
            if n == 0:
                out.append(0xE5)
                i += 2
            else:
                out += bytes([b[i + 2]]) * n
                i += 3
        else:
            out.append(b[i])
            i += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sna")
    ap.add_argument("--sym")
    ap.add_argument("--peek", nargs="*", default=[])
    ap.add_argument("--screen")
    a = ap.parse_args()
    h, mem = load(a.sna)
    w = lambda o: h[o] | h[o + 1] << 8  # noqa: E731
    syms = {}
    if a.sym:
        for line in open(a.sym):
            p = line.split()
            if len(p) >= 2 and p[1].startswith("#"):
                syms[p[0].lower()] = int(p[1][1:], 16)
    pc = w(0x23)
    near = ""
    if syms:
        best = max(((v, k) for k, v in syms.items() if v <= pc), default=None)
        if best:
            near = f" ({best[1]}+{pc - best[0]})"
    print(f"PC={pc:04X}{near} SP={w(0x21):04X} AF={h[0x12]:02X}{h[0x11]:02X} BC={w(0x13):04X} "
          f"DE={w(0x15):04X} HL={w(0x17):04X} IX={w(0x1F):04X} IY={w(0x1D):04X} "
          f"IFF1={h[0x1B]} IM={h[0x25]}")
    print(f"GA: pen={h[0x2E]} mode/rom={h[0x40]:02X} ram={h[0x41]:02X}")
    print("CRTC:", " ".join(f"R{i}={h[0x43 + i]:02X}" for i in range(18)))
    print("inks:", " ".join(f"{h[0x2F + i]:02X}" for i in range(17)))
    for p in a.peek:
        addr, _, ln = p.partition(":")
        ad = syms[addr.lower()] if addr.lower() in syms else int(addr, 16)
        n = int(ln, 0) if ln else 16
        print(f"{p} @{ad:04X}: " + " ".join(f"{b:02X}" for b in mem[ad:ad + n]))
    if a.screen:
        from PIL import Image
        base = ((h[0x43 + 12] >> 4) & 3) * 0x4000
        inks = [IDX_TO_RGB.get(h[0x2F + i] & 0x1F, (255, 0, 255)) for i in range(16)]
        img = Image.new("RGB", (320, 200))
        for y in range(200):
            off = base + (y % 8) * 0x800 + (y // 8) * 80
            for xb in range(80):
                for i, p in enumerate(mode0_unpack(mem[off + xb])):
                    img.putpixel((xb * 4 + i * 2, y), inks[p])
                    img.putpixel((xb * 4 + i * 2 + 1, y), inks[p])
        img.resize((640, 400), Image.NEAREST).save(a.screen)
        print(f"screen @{base:04X} -> {a.screen}")


if __name__ == "__main__":
    main()
