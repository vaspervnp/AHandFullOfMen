# A Handful of Men

A tactical stealth game for the Amstrad CPC 6128, an 8-bit demake inspired by
*Commandos: Behind Enemy Lines*. The design brief is in
[AHandFullOfMen.md](AHandFullOfMen.md).

## Build

Requires `rasm` (3.x), `iDSK`, Python 3 with Pillow and the `z80` package,
and the Caprice32 snap for the emulator tests.

```bash
./build.sh            # assets -> rasm -> build/handful_of_men.{sna,dsk} -> tests
./build.sh --no-test  # build only
tools/play            # play the snapshot in Caprice32 (or: tools/play cpcemu)
```

On a real CPC or in an emulator: insert `build/handful_of_men.dsk` and type
`RUN"DISC`.

## Controls

| Key | Action |
| --- | --- |
| Cursor keys / QAOP / joystick | move the crosshair (push against an edge to scroll) |
| Space / Copy / Fire | select a commando, order a move, or attack what is under the cursor (knife, harpoon, rifle) |
| Return / Fire 2, C | toggle crawling |
| 1, 2, 3 | select Green Beret, Marine, Sniper |
| D | Green Beret: drop the radio decoy, press again to make it ping |
| G | Green Beret: grab / drop the barrel or body within reach |
| V | pin the vision cone of the guard under the cursor (pointing at a guard shows it too) |
| Esc | back to the title menu |

The title menu lists these shortcuts too. Space or Fire starts the mission.

## Layout

```
src/main.asm             entry point, main loop, memory map, variables
src/defs.asm             constants, entity struct, key codes
src/crtc/                video init, palette, VSYNC interrupt
src/render/              tile engine, masked blitter, renderer, HUD
src/input/               keyboard matrix, joystick/QAOP, cursor
src/entities/            entity helpers, commandos, guards, barrels/explosions/dragging
src/ai/                  vision geometry + LOS, guard state machine, noise
src/audio/               AY-3-8912 access, sound effects
src/missions/            mission spawn and patrol data
src/menu.asm             title menu (banner + keyboard shortcuts)
src/boot/loader.asm      disk loader (AMSDOS, pages sprites into bank 4)
assets/                  PNG sheets (+ manifests), ASCII maps, DISC.BAS, splash
tools/                   gen_art, png2cpc, map2asm, cpcsim, cpcemu, snapinfo, play
tests/                   scripted-input scenarios + assertions
```

## Memory map (CPC 6128)

| Range | Contents |
| --- | --- |
| `&0040-&3FFF` | code, tables, variables, stack |
| `&4000-&7FFF` | tiles, font, title art, mission data, live map. Sprite banks 4 (Green Beret, guard, effects) and 5 (Marine, Sniper) are paged in here while blitting |
| `&8000-&BFFF` | screen buffer B |
| `&C000-&FFFF` | screen buffer A |

The brief put graphics at `&8000`. The game uses that range for a second
screen instead, so it can double-buffer without flicker, and keeps sprites in
the 6128's extra RAM.

## Asset pipeline

`tools/gen_art.py` currently draws placeholder sprites, tiles, font and
portraits procedurally. Blender/Aseprite renders replace them by keeping
the same sheet layout and palette. `tools/png2cpc.py` converts sheets to
Mode 0 data (masked sprites as mask/pixel byte pairs). `tools/map2asm.py`
converts `assets/maps/*.txt`.

## Mission 1: Baptism of Fire

Destroy the radio tower inside the compound, then get every surviving
commando into the truck at the road junction. Only a bullet sets off a
barrel, and the blast must be close to the tower's base. Explosions raise
the base alarm, and you then have 60 seconds before reinforcements arrive.
Finishing without ever raising the alarm counts as a bonus objective.

| Commando | Abilities |
| --- | --- |
| Tiny, Green Beret | knife (silent, melee), radio decoy, drags barrels and bodies |
| Fins, Marine | swims, and can't be seen underwater; harpoon (silent, short range) |
| Duke, Sniper | rifle: long range, needs a clear line of sight, 5 rounds, loud |

## Stealth rules

- Guards see in a 60° cone. In the close zone they spot anything,
  including crawling commandos and bodies. In the far zone they only spot
  commandos standing up. Trees, rocks and buildings block their view.
- A spotted commando gets 1.5 s of grace (`!`). After that the guard opens
  fire, the siren sounds, and every guard joins the fight.
- Walking upright on snow is audible nearby. Guards come to investigate
  (`?`) for about 10 s, then go back to their patrol. The decoy draws guards
  from further away and holds them for about 25 s.

## Tests

`tests/run_tests.sh` assembles each `tests/tNN_*.asm` scenario. A scenario
is the full game with scripted joystick input (a `SCENARIO` macro) that
jumps to `&0000` when the script ends. Each scenario runs twice:

- in `tools/cpcsim.py`, a small Python CPC simulator, where `tests/check.py`
  asserts on RAM
- in Caprice32 (`tools/cpcemu`, headless), which takes a screenshot

The disk image is also booted with `RUN"DISC` and screenshotted.
