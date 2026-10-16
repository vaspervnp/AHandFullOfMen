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
tools/release.sh      # build + all tests + fuzz soak -> dist/*.dsk, *.sna, SHA256SUMS
```

On a real CPC or in an emulator: insert `build/handful_of_men.dsk` and type
`RUN"DISC`. The game needs 128K: a CPC 6128, or a 464/664 with a 64K
expansion. On a 64K machine the loader says so and returns to BASIC.

## Controls

| Key | Action |
| --- | --- |
| Cursor keys / QAOP / joystick | move the crosshair (push against an edge to scroll) |
| Space / Copy / Fire | select a commando, order a move, or attack what is under the cursor (knife, harpoon, rifle, syringe) |
| Return / Fire 2, C | toggle crawling |
| 1, 2, 3 | select a commando (the HUD portraits, left to right) |
| D | first ability of the selected commando (see the tables below) |
| G | second ability of the selected commando |
| V | pin the vision cone of the guard under the cursor (pointing at a guard shows it too) |
| Esc | back to the title menu |

The title menu lists these shortcuts too. Keys 1 to 4 on the menu pick the
mission. Space or Fire opens its briefing (objectives, and what each
commando's D and G do), and pressing it again starts the mission.
Accomplishing a mission moves the menu on to the next one.

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

Green Beret keys: D drops the radio decoy (press again to make it ping),
G grabs or drops the barrel or body within reach.

## Mission 2: Inferno

A fuel depot on a Norwegian fjord, inside a fenced compound with a single
gate on the south road. Blow the depot up with the Sapper's time bomb, then
get every survivor to the truck at the north-west end of the road. The
same 60-second alarm rule applies, and the bomb always raises the alarm,
so plant it, then run.

| Commando | Abilities |
| --- | --- |
| Tiny, Green Beret | as in Mission 1 |
| Inferno, Sapper | D: lays a bear trap at his feet (2 of them); a sentry walking onto it dies silently. G: plants the time bomb (1): 10 seconds, then a blast three tiles across that destroys the depot if it is close enough. He doesn't fight |
| Spooky, Spy | D: puts on or takes off a German uniform; in it, sentries take him for one of their own. G: in uniform, talks to the sentry next to him, who turns to face him and stands there for as long as he stays close. Attack: syringe (silent, melee) |

## Mission 3: Rough Waters

A harbour with a U-boat moored at a wooden pier, fuel barrels stacked
beside it. The dock yard is fenced, with one gate on the east road, but
a canal runs down the west edge: the Marine's way in. Shoot the barrels
next to the U-boat to sink her, then get the survivors to the truck south
of the gate. Squad: Marine, Sniper, Spy (abilities as above).

## Mission 4: A Bridge Too Far

A railway crosses a river on a steel bridge, with sandbagged posts at
both ends. Blow the bridge with the Sapper's time bomb, then get the
survivors to the truck in the camp on the north bank. Once the span is
down, the frozen ford in the west is the only way across. Squad: Green
Beret, Sapper, Sniper (abilities as above).

## Stealth rules

- Guards see in a 60° cone. In the close zone they spot anything,
  including crawling commandos and bodies. In the far zone they only spot
  commandos standing up. Trees, rocks and buildings block their view.
- A spotted commando gets 1.5 s of grace (`!`). After that the guard opens
  fire, the siren sounds, and every guard joins the fight.
- Walking upright on snow is audible nearby. Guards come to investigate
  (`?`) for about 10 s, then go back to their patrol. The decoy draws guards
  from further away and holds them for about 25 s.

## Movement

Commandos route around trees, rocks, buildings, fences and water, so
clicking behind an obstacle walks around it. The Marine swims instead. A
click nobody can reach is ignored. When a commando is ordered to attack,
he re-plans his route as the target moves. Guards investigating a noise,
and returning to their patrol afterwards, route around obstacles too.

If nothing is in the way, the unit just walks straight there. Otherwise
the game floods outward from the clicked tile on the 40×32 grid (8-way,
no corner cutting) until it reaches the walker, then keeps only the turns
as waypoints. The search runs in the background, in the time the main
loop would otherwise spend waiting for the next frame, so the unit may
pause for a few ticks before it sets off on a long detour. Only one
search runs at a time; other units wait their turn.

## Frame rate

The game logic runs at 25 Hz: each tick has two frames of time. Measured
on Caprice32 across the test scenarios, almost every tick fits in two
frames. The exceptions are the first ticks after a mission starts and the
tick the radio tower falls. Things that make this possible:

- The renderer caches what each screen buffer shows. It restores and
  redraws only sprites that moved or changed, plus anything overlapping
  them, instead of the whole sprite list.
- Vision cones are cast in three passes over three ticks, then swapped in.
  A cone therefore trails a moving guard by a few ticks.
- HUD text redraws only the characters that changed, and portraits only
  when their highlight or health changes.
- Path searches run in idle time (see Movement).
- When the tower falls, only its tiles are redrawn. Each path search
  builds its walk grid straight from the live map, a few rows per idle
  slice, so map changes need no grid upkeep.

Scrolling still means redrawing the whole view, which takes about 5 frames
of work. That work is spread over the hidden buffer, four tile rows per
tick, while the old picture stays on screen. The new view is shown when
complete, and the camera waits for it before moving again. The game keeps
running at 25 Hz; only the picture updates more slowly while scrolling.

## Layout

```
src/main.asm             entry point, main loop, memory map, variables
src/defs.asm             constants, entity struct, key codes
src/crtc/                video init, palette, VSYNC interrupt
src/render/              tile engine, masked blitter, renderer, HUD
src/input/               keyboard matrix, joystick/QAOP, cursor
src/entities/            entity helpers, commandos, guards, barrels/explosions/dragging,
                         role abilities (Sapper, Spy)
src/ai/                  vision geometry + LOS, guard state machine, noise, pathfinding
src/audio/               AY-3-8912 access, sound effects
src/missions/            mission table + per-mission spawn and patrol data
src/menu.asm             title menu (banner + keyboard shortcuts)
src/boot/loader.asm      disk loader (AMSDOS, pages sprites into bank 4)
assets/                  .blend + .aseprite sources, renders, PNG sheets (+ manifests),
                         ASCII maps, DISC.BAS, splash
tools/                   art pipeline (blender/, aseprite/, render_assets.sh, renders2sheet,
                         assemble_art), png2cpc, map2asm, cpcsim, cpcemu, snapinfo, play
tests/                   scripted-input scenarios + assertions
```

## Memory map (CPC 6128)

| Range | Contents |
| --- | --- |
| `&0040-&3EFF` | code, tables, variables |
| `&3F00-&3FFF` | stack (measured depth is about 30 bytes; tests check a canary) |
| `&4000-&7FFF` | tiles, font, portraits, texts, mission spawn lists, live map, path grids, render caches. Paged over by bank 4 (Green Beret, guard, cursor, effects), 5 (Marine, Sniper, menu music) or 6 (Sapper, Spy) while blitting, and by bank 7 (title banner, mission maps) when the menu or a mission loads |
| `&8000-&BFFF` | screen buffer B |
| `&C000-&FFFF` | screen buffer A |

The brief put graphics at `&8000`. The game uses that range for a second
screen instead, so it can double-buffer without flicker, and keeps sprites in
the 6128's extra RAM.

## Asset pipeline

All art lives in Blender scenes and Aseprite documents. Run
`tools/render_assets.sh` after editing them (about 2 minutes). The PNG
sheets it writes are committed, so `./build.sh` doesn't need either tool.

| Source | Contents |
| --- | --- |
| `assets/blender/*.blend` | operatives and sentry (posed by object name), radio tower, pine, rock, barrel, explosion frames, truck, HUD portrait busts, title banner |
| `assets/aseprite/terrain.aseprite` | 8×8 terrain, building and HUD tiles; the prop cells hold the ground the Blender props are composited onto |
| `assets/aseprite/font.aseprite` | 4×8 HUD font |
| `assets/aseprite/cursor.aseprite` | crosshair, attack marker, `!`/`?` alerts, decoy icon |

1. **Blender** renders each subject headless (`tools/blender/hfm_render.py`).
   It opens the `.blend` if it exists; the first run builds the low-poly
   scene from code and saves it. Characters get 7 poses × 5 directions;
   props and banner are stills. Workbench flat shading with no
   anti-aliasing gives exact palette colours, and the render size includes
   the Mode 0 2:1 squash.
2. **Aseprite** exports the hand-drawn documents.
3. **`renders2sheet.py` / `assemble_art.py`** shrink each 8×4 render block
   to one Mode 0 pixel (its most common colour). They add outlines, mirror
   the west-facing frames, and composite the props onto the terrain tiles.
4. **Aseprite** clamps every generated sheet to the 16-colour CPC palette
   with 2:1 pixel ratio, saving an editable copy (`assets/aseprite/<sheet>.aseprite`)
   next to the PNG it exports.
5. **`tools/png2cpc.py`** (run by the build) encodes Mode 0 bytes and masks.
   `tools/map2asm.py` converts `assets/maps/*.txt`.

### Music

The title screen plays a march, and the debrief a fanfare or a lament.
They're written as plain text in `assets/music/*.txt`: two voices of
note / hold / rest tokens, with a tempo and start volumes. The build turns
them into AY data with `tools/music2asm.py`; it lives in RAM bank 5, after
the Marine and Sniper sheets. The player (`src/audio/music.asm`) runs only
on those pages, so in-game sound is effects and the siren as before.
`tools/psg2wav.py build/handful_of_men.sna title.wav --notes` renders what
the AY plays to a WAV file and lists the notes.

## Tests

`tests/run_tests.sh` assembles each `tests/tNN_*.asm` scenario. A scenario
is the full game with scripted joystick input (a `SCENARIO` macro) that
jumps to `&0000` when the script ends. Each scenario runs twice:

- in `tools/cpcsim.py`, a small Python CPC simulator, where `tests/check.py`
  asserts on RAM. It also compares the final screen against the same
  scenario built with `REF_RENDER=1`, which redraws everything every frame,
  and checks the stack canary.
- in Caprice32 (`tools/cpcemu`, headless), which takes a screenshot

The disk image is also booted with `RUN"DISC` and screenshotted.

`tests/fuzz.py --seeds 1-8 --ticks 3000` is a soak test. It plays the game
with random stick, fire and command keys (ESC included, so game overs and
the menu are played through too) and fails on a stray PC or SP, a hang, an
early stop, a damaged stack canary or a corrupt entity table.

`tests/frames.py` reports frames per game tick for every scenario: from
cpcsim, or exactly from Caprice32 with `--cap32`. For the Caprice32 numbers,
the TEST build writes its histogram onto the screen and the script decodes
it from the screenshot. `tools/profile_calls.py <test>` shows inclusive time
per routine.
