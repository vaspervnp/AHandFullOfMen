#!/usr/bin/env python3
"""Play the training course from the title menu, like a player would, and
record it as a video.

Usage: autoplay.py [--video out.mp4] [--sna build/handful_of_men.sna]

A small bot drives the real game in tools/cpcsim.py through the keyboard
matrix only: joystick directions move the crosshair (it pushes against the
screen edges to scroll), Space clicks, 1/2/3, C, V pick men and crawl. It
reads the game state from RAM (cursor, camera, entities) to aim, so it
works whatever the exact timings. Frames go to ffmpeg as raw RGB at 25 fps
(every other 50 Hz frame), the AY registers are logged every frame and
synthesised (tools/psg2wav.py) into the soundtrack.
"""
import argparse
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpcsim  # noqa: E402
import psg2wav  # noqa: E402
from cpcsim import GA_INDEX_TO_RGB, mode0_unpack  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
UP, DOWN, LEFT, RIGHT = 0x90, 0x91, 0x92, 0x93     # joystick 0, matrix line 9
SPACE, KEY_0, KEY_1, KEY_2, KEY_3, KEY_C, KEY_V = 0x57, 0x40, 0x80, 0x81, 0x71, 0x76, 0x67
ENT_SIZE, CAM_MAX_X, CAM_MAX_Y = 32, 20, 14
EF_DEAD, EF_BOARDED = 4, 16
F = {"type": 0, "x": 1, "y": 2, "state": 5, "flags": 8}


class Bot:
    def __init__(self, sna, sym, video):
        self.cpc = cpcsim.CPC(sna)
        self.cpc.slow = 1.25
        self.cpc.psg_log = []
        self.s = cpcsim.load_syms(sym)
        self.keys = set()
        self.frame = 0
        self.video = None
        self.tables = {}
        if video:
            self.video = subprocess.Popen(
                ["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                 "-s", "320x200", "-r", "25", "-i", "-", "-vf", "scale=960:600:flags=neighbor",
                 "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", video + ".silent.mp4"],
                stdin=subprocess.PIPE)

    # --- game state ---
    def b(self, name, off=0):
        return self.cpc.base_ram(self.s[name] + off)[0]

    def ent(self, i, field):
        return self.b("ent_table", i * ENT_SIZE + F[field])

    def alive(self, i):
        return self.ent(i, "type") and not self.ent(i, "flags") & (EF_DEAD | EF_BOARDED)

    # --- time ---
    def step(self, n=1):
        for _ in range(n):
            self.cpc.keys_down = set(self.keys)
            self.cpc.run_frame()
            self.frame += 1
            if self.video and self.frame % 2 == 0:
                self.video.stdin.write(self.grab())

    def wait(self, frames):
        self.keys = set()
        self.step(frames)

    def wait_until(self, cond, what, timeout=3000):
        self.keys = set()
        for _ in range(timeout):
            if cond():
                return
            self.step(1)
        raise SystemExit(f"autoplay: gave up waiting for {what} (frame {self.frame})\n" + self.dump())

    def dump(self):
        ents = " ".join(f"{i}:({self.ent(i, 'x')},{self.ent(i, 'y')}) st{self.ent(i, 'state')}"
                        f" f{self.ent(i, 'flags')}" for i in range(6))
        return (f"  cam ({self.b('cam_x')},{self.b('cam_y')}) cursor ({self.b('cursor_x')},"
                f"{self.b('cursor_y')}) sel {self.b('sel_cmd')} alarm {self.b('alarm')}\n  {ents}")

    def tap(self, key, hold=4):
        self.keys = {key}
        self.step(hold)
        self.keys = set()
        self.step(6)

    # --- the crosshair ---
    def view(self, wx, wy):
        """Scroll (by pushing the crosshair against an edge) until world point
        (wx, wy) is comfortably inside the view."""
        for _ in range(4000):
            cx, cy = self.b("cam_x"), self.b("cam_y")
            sx, sy = wx - cx * 4, wy - cy * 8
            push = set()
            if sx < 12 and cx > 0:
                push.add(LEFT)
            elif sx > 68 and cx < CAM_MAX_X:
                push.add(RIGHT)
            if sy < 24 and cy > 0:
                push.add(UP)
            elif sy > 124 and cy < CAM_MAX_Y:
                push.add(DOWN)
            if not push:
                return
            self.keys = push
            self.step(1)
        raise SystemExit("autoplay: could not scroll the view")

    def aim(self, tx, ty, done):
        """Steer the crosshair to screen (tx, ty) until done() holds."""
        for _ in range(3000):
            if done():
                self.keys = set()
                self.step(2)
                return
            cx, cy = self.b("cursor_x"), self.b("cursor_y")
            dx, dy = tx() - cx, ty() - cy
            push = set()
            if dx < 0:
                push.add(LEFT)
            elif dx > 0:
                push.add(RIGHT)
            if dy < -1:
                push.add(UP)
            elif dy > 1:
                push.add(DOWN)
            if abs(dx) <= 3 and abs(dy) <= 8 and self.keys:
                self.keys = set()                     # let go: slow steps from here
                self.step(2)
                continue
            self.keys = push
            self.step(2)
        raise SystemExit("autoplay: the crosshair never got there")

    def go(self, wx, wy):
        """Order the selected man to walk to world point (wx, wy)."""
        self.view(wx, wy)
        cam = lambda: (self.b("cam_x"), self.b("cam_y"))          # noqa: E731
        tx = lambda: wx - cam()[0] * 4                             # noqa: E731
        ty = lambda: wy - cam()[1] * 8 + 2                         # noqa: E731
        self.aim(tx, ty, lambda: abs(self.b("cursor_x") - tx()) <= 1
                 and abs(self.b("cursor_y") - ty()) <= 2)
        self.tap(SPACE)

    def point_at(self, i):
        """Put the crosshair on entity i (it may be moving)."""
        self.view(self.ent(i, "x"), self.ent(i, "y"))
        cam = lambda: (self.b("cam_x"), self.b("cam_y"))          # noqa: E731
        self.aim(lambda: self.ent(i, "x") - cam()[0] * 4,
                 lambda: self.ent(i, "y") - cam()[1] * 8 - 8,
                 lambda: self.b("cursor_ent") == i)

    def attack(self, i):
        self.point_at(i)
        self.tap(SPACE)

    def near(self, i, wx, wy, d=6):
        return abs(self.ent(i, "x") - wx) <= d and abs(self.ent(i, "y") - wy) <= d

    def grab(self):
        cpc = self.cpc
        inks = tuple(GA_INDEX_TO_RGB.get(cpc.inks[k] & 0x1F, (255, 0, 255)) for k in range(16))
        table = self.tables.get(inks)
        if table is None:                             # screen byte -> 2 Mode 0 pixels, doubled
            table = []
            for v in range(256):
                a, b = mode0_unpack(v)
                table.append(bytes(inks[a]) * 2 + bytes(inks[b]) * 2)
            self.tables[inks] = table
        base = ((cpc.crtc[12] >> 4) & 3) * 0x4000
        data = cpc.base_ram(base, 0x4000)
        rows = []
        for y in range(200):
            off = (y % 8) * 0x800 + (y // 8) * 80
            rows.append(b"".join(table[v] for v in data[off:off + 80]))
        return b"".join(rows)

    def finish(self, video):
        if not self.video:
            return
        self.video.stdin.close()
        self.video.wait()
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "sound.wav")
            psg2wav.write_wav(self.cpc.psg_log, wav)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", video + ".silent.mp4",
                            "-i", wav, "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
                            "-shortest", video], check=True)
        os.remove(video + ".silent.mp4")


def play_training(bot):
    def say(msg):                                     # a lesson: give the tip time to read
        print(f"autoplay: {bot.frame:6d} {msg}")
        bot.wait(60)
    bot.wait(150)                                     # the title menu
    bot.tap(KEY_0)
    bot.wait(100)
    bot.tap(SPACE)                                    # briefing
    bot.wait(200)
    bot.tap(SPACE)                                    # go in
    bot.wait_until(lambda: bot.b("tick") > 4 and bot.b("cur_mission") == 7, "the course")
    bot.wait(60)
    beret, marine, sniper, post, patrol, barrel = 0, 1, 2, 3, 4, 5

    say("walk east")
    bot.tap(KEY_1)
    bot.go(46, 231)
    bot.wait_until(lambda: bot.near(beret, 46, 231), "the Beret to walk east")

    say("the Marine swims the river")
    bot.tap(KEY_2)
    bot.go(46, 135)
    bot.wait_until(lambda: bot.near(marine, 46, 135), "the Marine to swim across", 4000)

    say("Beret and Sniper to the bridge")
    bot.tap(KEY_1)
    bot.go(122, 191)
    bot.tap(KEY_3)
    bot.go(106, 199)
    bot.wait_until(lambda: bot.near(beret, 122, 191), "the Beret at the bridge", 4000)

    say("crawl up behind the sentry and knife him")
    bot.tap(KEY_1)
    bot.tap(KEY_C)
    bot.go(122, 147)
    bot.wait_until(lambda: bot.near(beret, 122, 147, 5), "the Beret behind the sentry", 4000)
    bot.attack(post)
    bot.wait_until(lambda: not bot.alive(post), "the sentry to fall", 1500)

    say("watch the patrol's cone, then take him from behind")
    bot.point_at(patrol)
    bot.tap(KEY_V)
    bot.wait(120)
    bot.attack(patrol)
    bot.wait_until(lambda: not bot.alive(patrol), "the patrol to fall", 3000)
    bot.tap(KEY_V)                                    # unpin the cone
    bot.tap(KEY_C)                                    # stand up again

    say("the Sniper shoots the barrel by the mast")
    bot.tap(KEY_3)
    bot.go(110, 79)
    bot.wait_until(lambda: bot.near(sniper, 110, 79), "the Sniper in position", 4000)
    bot.attack(barrel)
    bot.wait_until(lambda: bot.b("target_down"), "the mast to fall", 1500)
    bot.wait(80)

    say("everyone into the truck")
    for key, man in ((KEY_3, sniper), (KEY_1, beret), (KEY_2, marine)):
        bot.tap(key)
        bot.go(146, 26)
    bot.wait_until(lambda: bot.b("game_over") == 2, "the squad to get away", 6000)
    say("course complete")
    bot.wait(400)                                     # the debrief
    bot.tap(SPACE)
    bot.wait(150)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sna", default=os.path.join(ROOT, "build", "handful_of_men.sna"))
    ap.add_argument("--video")
    a = ap.parse_args()
    bot = Bot(a.sna, os.path.splitext(a.sna)[0] + ".sym", a.video)
    play_training(bot)
    bot.finish(a.video)
    print(f"autoplay: done in {bot.frame} frames ({bot.frame / 50:.0f} s)"
          + (f" -> {a.video}" if a.video else ""))


if __name__ == "__main__":
    main()
