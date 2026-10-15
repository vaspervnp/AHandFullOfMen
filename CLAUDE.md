# Notes for working on this repo

- Build + test: `./build.sh` (needs a few minutes for the Caprice32 runs);
  quick loop: `./build.sh --no-test && tests/run_tests.sh --no-cap32`.
- Debug a scenario: `cd build && python3 ../tools/cpcsim.py tests/t01_boot.sna
  --sym tests/t01_boot.sym --peek tick:2 --trace 40 --screen out.png`.
- Profile: `cpcsim.py ... --profile 30` samples the PC after frame 30 and
  prints a per-routine breakdown. Frames per game tick (target 2 = 25 Hz):
  `--peek tick:1`, then compare against `frames=`.
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
- `tools/cpcsim.py` counts raw Z80 T-states (no CPC 4T rounding), so it's
  optimistic on timing.

## Hardware notes
- Mode 0 byte layout: the left pixel's bits 0..3 sit in bits 7,3,5,1. The
  table in brief §4.3 is wrong.
- `LDI` increments DE as a 16-bit pair. Code that rewinds a screen pointer
  with `E-=4` must borrow into D (see `draw_tile_de`).
