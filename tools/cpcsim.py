#!/usr/bin/env python3
"""Minimal Amstrad CPC 6128 simulator for development and regression tests.

Runs a firmware-free program from a .sna snapshot using the `z80` Python
package (kosarev/z80). Emulates just what A Handful of Men touches:
Gate Array (pens, mode, 128K RAM banking), CRTC registers (screen base),
PPI + AY port A (keyboard matrix), VSYNC on PPI port B and the 300 Hz
interrupt. Timing is plain Z80 T-states (no CPC wait-state rounding), so
cycle counts are ~15-25% optimistic versus real hardware; Caprice32
(tools/cpcemu) remains the reference for timing and display.

Usage:
    cpcsim.py game.sna [--sym game.sym] [--frames N] [--keys SCRIPT]
              [--screen out.png] [--peek name[:len] ...] [--profile]

--keys: comma list of "frame-frame:KEY+KEY" (keys are matrix codes like
        57 for SPACE, see src/defs.asm) e.g. "10-20:02,25-26:57".
Stops after --frames or when the program jumps to &0000 (test end).
"""
import argparse
import os
import sys

import z80

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from snapinfo import IDX_TO_RGB, load  # noqa: E402
from cpcpal import mode0_unpack  # noqa: E402

LINE_T = 256            # 64 us per scanline at 4 MHz
FRAME_LINES = 312
FRAME_T = LINE_T * FRAME_LINES
INT_LINES = [2 + 52 * i for i in range(6)]   # first one lands inside VSYNC
VSYNC_LINES = 8
CHUNK_T = 64

# GA hardware colour number (0..31) -> RGB, from the colour index the GA uses
GA_INDEX_TO_RGB = IDX_TO_RGB

RAM_CONFIGS = {   # config -> bank in each 16K window
    0: (0, 1, 2, 3), 1: (0, 1, 2, 7), 2: (4, 5, 6, 7), 3: (0, 3, 2, 7),
    4: (0, 4, 2, 3), 5: (0, 5, 2, 3), 6: (0, 6, 2, 3), 7: (0, 7, 2, 3),
}


class CPC:
    def __init__(self, sna_path):
        hdr, mem = load(sna_path)
        if len(mem) < 0x20000:
            mem.extend(bytes(0x20000 - len(mem)))
        self.banks = [bytearray(mem[i * 0x4000:(i + 1) * 0x4000]) for i in range(8)]
        self.m = z80.Z80Machine()
        w = lambda o: hdr[o] | hdr[o + 1] << 8  # noqa: E731
        m = self.m
        m.af = hdr[0x11] | hdr[0x12] << 8
        m.bc, m.de, m.hl = w(0x13), w(0x15), w(0x17)
        m.ix, m.iy, m.sp, m.pc = w(0x1F), w(0x1D), w(0x21), w(0x23)
        self.crtc = list(hdr[0x43:0x43 + 18])
        self.crtc_sel = 0
        self.inks = list(hdr[0x2F:0x2F + 17])
        self.pen = 0
        self.ram_cfg = 0
        self.mapping = RAM_CONFIGS[0]
        for win in range(4):
            m.set_memory_block(win * 0x4000, bytes(self.banks[self.mapping[win]]))
        self.ppi_c = 0
        self.psg_reg = 0
        self.psg = [0] * 16
        self.keys_down = set()
        self.t = 0
        self.frame_start = 0
        self.int_pending = False
        self.frame = 0
        self.stopped = False
        self.profile = {}
        self.trace = None           # deque of recent PCs when tracing
        self.samples = None         # PC samples (one per chunk) when profiling
        self.slow = 1.0             # T-state multiplier (CPC wait states)
        self.psg_log = None         # list of AY register snapshots, one per frame
        m.set_output_callback(self.out)
        m.set_input_callback(self.inp)
        m.set_breakpoint(0)

    # --- memory banking -----------------------------------------------------
    def set_ram(self, cfg):
        new = RAM_CONFIGS[cfg & 7]
        if new == self.mapping:
            return
        mem = self.m.memory
        for win in range(4):
            if new[win] != self.mapping[win]:
                self.banks[self.mapping[win]][:] = mem[win * 0x4000:(win + 1) * 0x4000]
        for win in range(4):
            if new[win] != self.mapping[win]:
                mem[win * 0x4000:(win + 1) * 0x4000] = self.banks[new[win]]
        self.mapping = new

    def base_ram(self, addr, n=1):
        """Read base 64K RAM regardless of the current mapping."""
        out = bytearray()
        mem = self.m.memory
        for a in range(addr, addr + n):
            win = a >> 14
            bank = win      # base RAM bank for this window
            if self.mapping[win] == bank:
                out.append(mem[a])
            else:
                out.append(self.banks[bank][a & 0x3FFF])
        return out

    # --- I/O ----------------------------------------------------------------
    def out(self, port, value):
        hi = port >> 8
        if (hi & 0xC0) == 0x40:                 # Gate Array / PAL
            fn = value >> 6
            if fn == 0:
                self.pen = 16 if value & 0x10 else value & 15
            elif fn == 1:
                self.inks[self.pen] = value & 0x1F
            elif fn == 3:
                self.set_ram(value)
        if (hi & 0x40) == 0:                    # CRTC
            if (hi & 3) == 0:
                self.crtc_sel = value & 31
            elif (hi & 3) == 1 and self.crtc_sel < 18:
                self.crtc[self.crtc_sel] = value
        if (hi & 0x08) == 0:                    # PPI
            reg = hi & 3
            if reg == 0:
                self.ppi_a = value
            elif reg == 2:
                self.ppi_c = value
                ctl = value >> 6
                if ctl == 3:
                    self.psg_reg = getattr(self, "ppi_a", 0) & 15
                elif ctl == 2:
                    self.psg[self.psg_reg] = getattr(self, "ppi_a", 0)

    def inp(self, port):
        hi = port >> 8
        if (hi & 0x08) == 0:
            reg = hi & 3
            if reg == 1:                        # port B: VSYNC in bit 0
                line = (self.t - self.frame_start) // LINE_T
                return 0x1E | (1 if line < VSYNC_LINES else 0)
            if reg == 0:                        # port A: PSG read
                if (self.ppi_c >> 6) == 1 and self.psg_reg == 14:
                    row = self.ppi_c & 15
                    v = 0xFF
                    for k in self.keys_down:
                        if k >> 4 == row:
                            v &= ~(1 << (k & 7))
                    return v & 0xFF
                return 0xFF
        return 0xFF

    # --- execution ----------------------------------------------------------
    def run_frame(self):
        m = self.m
        start = self.t
        self.frame_start = start
        next_int = [start + l * LINE_T for l in INT_LINES]
        end = start + FRAME_T
        while self.t < end and not self.stopped:
            if next_int and self.t >= next_int[0]:
                next_int.pop(0)
                self.int_pending = True
            if self.int_pending and m.on_handle_active_int():
                self.int_pending = False
            chunk = 1 if self.trace is not None else CHUNK_T
            if self.samples is not None:
                self.samples.append(m.pc)
            if self.trace is not None:
                self.trace.append(m.pc)
            m.ticks_to_stop = chunk
            events = m.run()
            ran = chunk - m.ticks_to_stop if m.ticks_to_stop else chunk
            self.t += ran if self.slow == 1.0 else int(ran * self.slow + 0.5)
            if events & m._BREAKPOINT_HIT:
                if m.pc == 0:
                    self.stopped = True
                    break
        self.frame += 1
        if self.psg_log is not None:
            self.psg_log.append(list(self.psg[:14]))

    def screen_png(self, path):
        from PIL import Image
        base = ((self.crtc[12] >> 4) & 3) * 0x4000
        inks = [GA_INDEX_TO_RGB.get(self.inks[i] & 0x1F, (255, 0, 255)) for i in range(16)]
        data = self.base_ram(base, 0x4000)
        img = Image.new("RGB", (320, 200))
        px = img.load()
        for y in range(200):
            off = (y % 8) * 0x800 + (y // 8) * 80
            for xb in range(80):
                for i, p in enumerate(mode0_unpack(data[off + xb])):
                    px[xb * 4 + i * 2, y] = inks[p]
                    px[xb * 4 + i * 2 + 1, y] = inks[p]
        img.resize((640, 400), Image.NEAREST).save(path)


def parse_keys(spec):
    script = []
    for part in filter(None, (spec or "").split(",")):
        rng, _, keys = part.partition(":")
        a, _, b = rng.partition("-")
        a = int(a)
        b = int(b) if b else a
        script.append((a, b, [int(k, 16) for k in keys.split("+")]))
    return script


def load_syms(path):
    syms = {}
    if path:
        for line in open(path):
            p = line.split()
            if len(p) >= 2 and p[1].startswith("#"):
                syms[p[0].lower()] = int(p[1][1:], 16)
    return syms


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sna")
    ap.add_argument("--sym")
    ap.add_argument("--frames", type=int, default=500)
    ap.add_argument("--keys")
    ap.add_argument("--screen")
    ap.add_argument("--peek", nargs="*", default=[])
    ap.add_argument("--profile", type=int, default=0, metavar="SKIP",
                    help="sample the PC after SKIP frames and print a per-routine profile")
    ap.add_argument("--slow", type=float, default=1.0,
                    help="T-state multiplier approximating CPC wait states (~1.25)")
    ap.add_argument("--trace", type=int, default=0,
                    help="print the last N program counters before stopping")
    a = ap.parse_args()
    cpc = CPC(a.sna)
    cpc.slow = a.slow
    syms = load_syms(a.sym)
    if a.trace:
        import collections
        cpc.trace = collections.deque(maxlen=a.trace)
    script = parse_keys(a.keys)
    for f in range(a.frames):
        cpc.keys_down = {k for (s, e, ks) in script if s <= f <= e for k in ks}
        if a.profile and f == a.profile:
            cpc.samples = []
        cpc.run_frame()
        if cpc.stopped:
            break
    m = cpc.m
    print(f"frames={cpc.frame} stopped_at_0={cpc.stopped} PC={m.pc:04X} SP={m.sp:04X} "
          f"R12={cpc.crtc[12]:02X} ram=C{cpc.ram_cfg:X}")
    for p in a.peek:
        name, _, ln = p.partition(":")
        base, _, off = name.partition("+")
        addr = syms[base.lower()] if base.lower() in syms else int(base, 16)
        addr += int(off, 0) if off else 0
        n = int(ln, 0) if ln else 16
        print(f"{name} @{addr:04X}: " + " ".join(f"{b:02X}" for b in cpc.base_ram(addr, n)))
    if cpc.samples:
        import bisect
        import collections
        top = sorted((v, k) for k, v in syms.items() if "." not in k)
        hist = collections.Counter()
        for pc in cpc.samples:
            i = bisect.bisect_right(top, (pc, "~")) - 1
            hist[top[i][1] if i >= 0 else "?"] += 1
        total = len(cpc.samples)
        print(f"profile: {total} samples over {cpc.frame - a.profile} frames")
        for name, n in hist.most_common(15):
            print(f"  {100 * n / total:5.1f}%  {name}")
    if cpc.trace:
        names = sorted((v, k) for k, v in syms.items())
        def where(pc):
            import bisect
            i = bisect.bisect_right(names, (pc, "~")) - 1
            return f"{names[i][1]}+{pc - names[i][0]}" if i >= 0 else "?"
        last = None
        for pc in cpc.trace:
            if pc != last:
                print(f"  {pc:04X} {where(pc)}")
            last = pc
    if a.screen:
        cpc.screen_png(a.screen)
        print(f"screen -> {a.screen}")


if __name__ == "__main__":
    main()
