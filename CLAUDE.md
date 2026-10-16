# Notes for working on this repo

- Build + test: `./build.sh` (needs a few minutes for the Caprice32 runs);
  quick loop: `./build.sh --no-test && tests/run_tests.sh --no-cap32`.
- Soak: `tests/fuzz.py --seeds 1-8 --ticks 3000` (random play, crash and
  hang detection). Release: `tools/release.sh` (build, all tests, fuzz,
  then `dist/*.dsk|sna` + SHA256SUMS).
- Debug a scenario: `cd build && python3 ../tools/cpcsim.py tests/t01_boot.sna
  --sym tests/t01_boot.sym --peek tick:2 --trace 40 --screen out.png`.
- Frame budget: `tests/frames.py` (cpcsim at `--slow 1.25`, which matches
  Caprice32 within a few ticks) or `tests/frames.py --cap32` (exact). Target:
  2 frames per tick everywhere.
- Profile: `tools/profile_calls.py t21_cone_patrol --from 60 --to 120`
  gives inclusive time per routine. `cpcsim.py ... --profile 30 --slow 1.25`
  gives flat PC samples.
- The z80 package clamps `ticks_to_stop` at 0, so stepping one instruction
  at a time counts every instruction as 1 T-state. Only chunked runs, with
  the calibrated `--slow`, give real timing.
- Test scripts are `db ticks, joy_bits, key` (key = matrix code or &FF), with
  a `SETUP` macro (required, may be empty) run after mission_load to stage
  entities.

## rasm gotchas
- Always pass `-amper` (`&` hex). Then `and`/`or`/`xor`/`mod` are the
  operators, and `/` is floating point, so use `>>` for integer division.
- Labels are case-insensitive. `key_down` collides with `KEY_DOWN`, and a
  label collides with a macro of the same name.
- `ld bc,(expr)` is a memory load. Don't parenthesise immediates.
- Snapshots for Caprice32 must be `-v2` (it rejects rasm's packed v3).
- Code after `bank 4` lands in bank 4. Test scripts are expanded inside
  main.asm via the `SCENARIO` macro for that reason.

## Emulators
- Caprice32 is the snap `caprice32`. It runs headless with SDL dummy drivers
  (see `tools/cpcemu`). `CAP32_WAITBREAK` waits for PC = &0000. The snap
  can't read `/tmp`, so keep images under the repo. `CAP32_SNAPSHOT` isn't
  recognised by 4.6.
- `/usr/share/cpcemu` is Marco Vieth's CPCEMU 2.5: interactive only, with no
  headless or dump options.
- `tools/cpcsim.py` counts raw Z80 T-states (no CPC 4T rounding). Pass
  `--slow 1.25` (tests/frames.py does this by default) to approximate the
  CPC's wait states.

## Art pipeline
- Art sources: `assets/blender/*.blend` and `assets/aseprite/{terrain,font,cursor}.aseprite`.
  Other `.aseprite` files are generated copies of the sheets. To rebuild a
  Blender subject from code, delete its `.blend`. There's no procedural
  2D art left (gen_art.py is gone).
- `tools/render_assets.sh`: Blender 5.2 (Windows, through WSL interop, with
  `\\wsl.localhost\...` paths), then renders2sheet, then the Aseprite batch
  run (built from source; path in the script).
- The Blender MCP calls time out unless Blender is open with the add-on.
  The headless CLI does the same job reproducibly.
- In Aseprite's indexed conversion, transparent pixels land on index 0
  (black). The Lua pass converts through an opaque magenta key at index 16
  instead.

## Game code rules
- Any change to `map_buf` must call `map_rect_changed` (a few tiles: walk
  grids, dirty tiles, cone recast) or `path_map_changed` plus a full
  redraw (mission load).
- Renderer: `render_frame` diffs draw items against a per-buffer cache.
  Anything drawn into the play area must go through it (draw items or
  tiles marked dirty), or the `REF_RENDER` comparison in tests/check.py
  fails.
- A full view redraw (camera scroll) is sliced over ticks (`REDRAW_SLICE`
  rows each); `render_frame` returns NC until the back buffer is complete
  and the main loop only flips on carry. The camera can't move while
  `redraw_row` is nonzero.
- Path searches are background jobs run from `pf_idle` (inside
  `wait_vsync` / `wait_frame`). `path_to` returns at once with a pending
  one-point path, so never assume a route exists the tick it's requested.
- Stack: 256 bytes at `&3F00`. Measured depth is about 30; TEST builds fill
  a canary at `&3F00-&3F7F`.
- rasm `-amper`: `&&` is not logical AND, so split asserts instead.

## Hardware notes
- Mode 0 byte layout: the left pixel's bits 0..3 sit in bits 7,3,5,1. The
  table in brief §4.3 is wrong.
- `LDI` increments DE as a 16-bit pair. Code that rewinds a screen pointer
  with `E-=4` must borrow into D (see `draw_tile_de`).
