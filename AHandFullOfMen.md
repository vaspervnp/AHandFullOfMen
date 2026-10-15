# MISSION BRIEFING & SYSTEM DIRECTIVE: A HANDFUL OF MEN (AMSTRAD CPC)

## 1. PROJECT OBJECTIVE
You are tasked with autonomously developing a complete, production-grade tactical stealth game titled **A Handful of Men** (an 8-bit demake inspired by *Commandos: Behind Enemy Lines*) for the **Amstrad CPC** microcomputer family.
The resulting project must compile cleanly to binary, assemble into a bootable CPC `.dsk` disk image and `.sna` snapshot, pass headless emulator validation, and be fully playable on authentic hardware and emulators.

---

## 2. HARDWARE TARGET & TECHNICAL SPECIFICATIONS

### 2.1 Target Machine
* **Primary Target:** Amstrad CPC 6128 (128 KB RAM, Z80A CPU @ 4.0 MHz, AY-3-8912 PSG sound, Gate Array, CRTC 6845).
* **Fallback Compatibility:** Modular memory layout so core levels can run on CPC 464 (64 KB) via multi-load, or utilize the 128 KB RAM banking (Gate Array `&7Fxx` page switching) for instant mission caching and double-buffered rendering.

### 2.2 Graphics & Memory Layout
* **Screen Mode:** Mode 0 ($160 \times 200$, 16 colours).
  * Pixels are rectangular (2:1 aspect ratio: twice as wide as they are tall).
  * Each byte encodes 2 adjacent Mode 0 pixels with standard CPC bit-interleaving:
    * `Pixel 0: Bit 1, Bit 5, Bit 3, Bit 7`
    * `Pixel 1: Bit 0, Bit 4, Bit 2, Bit 6`
* **Video RAM Architecture:** Standard CPC screen is 16 KB mapped at `&C000–&FFFF`.
  * CRTC scanline stride: line $y$ within character row is offset by `(y % 8) * &0800 + (y / 8) * 80`.
* **Memory Map (CPC 6128 Bank 0 configuration):**
  * `&0000–&003F`: Z80 Restart vectors and hardware interrupt jump tables (IM 1 / 300Hz interrupt counter).
  * `&0040–&3FFF`: Core Engine, Input Drivers, AI State Machines, Vision Raycaster, Math LUTs.
  * `&4000–&7FFF`: Level Maps, Collision Matrix ($160 \times 100$ 4-bit cells), Patrol Waypoints, Entity Descriptors.
  * `&8000–&BFFF`: Mode 0 Tile Sets, Sprite Bitmaps, Mask Tables, AY-3-8912 Chiptune/SFX Sound Driver.
  * `&C000–&FFFF`: Primary Video Display Buffer (or Double Buffer via RAM Bank 3 switching at `&7FC3`).

---

## 3. MANDATORY TOOLCHAIN & MCP INTEGRATIONS

All source code, assets, builds, and automated tests must strictly adhere to the following command-line tools and Model Context Protocol (MCP) servers:

| Tool / Server | Invocation / Interface | Role in Project |
| :--- | :--- | :--- |
| **RASM** | `rasm` | High-performance Z80 Assembler. Generates raw binaries (`.bin`), snapshots (`.sna`), and symbol tables (`.sym`). |
| **iDSK** | `idsk` | Amstrad CPC Floppy Disk Image (`.dsk`) manager. Creates, formats, and injects executables into AMSDOS disk containers. |
| **Caprice32** | `caprice32` / snap tools | CPC Snapshot inspection and execution harness. |
| **CPCEmu** | `cpcemu` | Headless emulator for automated CI regression testing and frame verification. |
| **Blender MCP** | `blender-mcp` | Direct 3D automation: low-poly character/vehicle modeling, isometric rendering (8 rotations), and Mode 0 anamorphic scaling. |
| **Aseprite MCP** | `aseprite-mcp` | Direct pixel art automation: palette quantization (CPC 16-color Gate Array), 2:1 pixel aspect ratio handling, sprite sheet slicing, and mask generation. |

---

## 4. AUTOMATED 3D-TO-8-BIT ASSET PIPELINE

Because the original PC *Commandos* used downscaled 3D pre-renders, the demake reproduces this authentic visual pipeline using **Blender MCP** and **Aseprite MCP**:

```
[Blender MCP: 3D Models] 
       │  (Isometric render, 8 compass angles, 2:1 aspect compensation)
       ▼
[Aseprite MCP: Pixel Processing]
       │  (Quantize to Amstrad CPC 16-color palette, dither, outline & slice)
       ▼
[Python Mode 0 Encoder: tools/png2cpc.py]
       │  (Convert interleaved 2-pixel/byte Mode 0 bitmaps + 1-byte masks)
       ▼
[RASM: src/data/sprites_data.asm]
```

### 4.1 Step 1: 3D Scene & Animation via Blender MCP
* **Rigging & Modeling:** Construct low-poly meshes for operatives (Green Beret, Marine, Sniper), sentries, vehicles (trucks, boats), and large scenery (radio tower, barracks).
* **Camera Setup:** Set orthographic camera with standard retro dimetric isometric angle ($30^\circ$ pitch) or true isometric ($35.264^\circ$).
* **Anamorphic Compensation for CPC Mode 0:** Because CPC Mode 0 pixels are twice as wide as tall, configure Blender render resolution with a $0.5\times$ horizontal factor (e.g. $12 \times 16$ sprite rendered at $12 \times 32$ or pre-squashed $6 \times 16$ grid) so the sprite retains correct proportions when rendered onto wide CPC pixels.
* **8-Directional Sequence Render:** Automate camera/model rotation in $45^\circ$ increments ($0^\circ$ North through $315^\circ$ North-West) across animation cycles (idle, walk, crawl, attack).

### 4.2 Step 2: Pixel Processing via Aseprite MCP
* **Palette Clamping:** Import Blender renders into Aseprite and apply the Amstrad CPC Gate Array 16-colour palette (fixed 27-colour hardware gamut).
* **Pixel Aspect Ratio:** Set Aseprite document pixel aspect ratio to `2:1` for accurate preview and manual pixel cleanup.
* **Sprite Sheet Slicing & Masking:** Use Aseprite MCP to generate:
  1. **Color Frame:** 16-color indexed bitmap for the commando/guard.
  2. **1-Bit Mask Frame:** White silhouette (`#FF`) where pixels exist, Black (`#00`) for transparency.
* **Export:** Batch export animation frames as sliced PNG sheets into `assets/sprites/`.

### 4.3 Step 3: CPC Mode 0 Binary Conversion (`tools/png2cpc.py`)
* Convert indexed PNG images into Mode 0 interleaved byte pairs.
* Each byte combines two adjacent pixels ($X_{even}$ and $X_{odd}$):
  * Bit 7: $P0_3$ | Bit 6: $P1_3$ | Bit 5: $P0_1$ | Bit 4: $P1_1$
  * Bit 3: $P0_2$ | Bit 2: $P1_2$ | Bit 1: $P0_0$ | Bit 0: $P1_0$
* Generates `.asm` source includes (`DB &xx, &xx...`) or raw `.bin` data blobs loaded directly into RAM Bank 2.

---

## 5. BUILD AUTOMATION & REGRESSION HARNESS

The project must include automated build scripts that execute without interactive prompts:

```bash
#!/usr/bin/env bash
set -e

# 1. Clean previous build artifacts
rm -rf build && mkdir -p build

# 2. Convert art assets from Aseprite/Blender pipeline to Mode 0 binaries
python3 tools/png2cpc.py assets/sprites/ build/sprites.bin
python3 tools/png2cpc.py assets/tiles/ build/tiles.bin

# 3. Assemble core binary and generate symbol map with RASM
rasm src/main.asm -o build/handful_of_men -b -sl -sp

# 4. Assemble bootloader / BASIC loader
rasm src/boot/loader.asm -o build/loader -b

# 5. Generate bootable DSK image using iDSK
idsk build/handful_of_men.dsk -n
idsk build/handful_of_men.dsk -i build/loader.bin -t 1 -e 4000 -c 4000
idsk build/handful_of_men.dsk -i build/handful_of_men.bin -t 1 -e 1000 -c 1000
idsk build/handful_of_men.dsk -i assets/disc/DISC.BAS -t 0

# 6. Generate direct testing snapshot (.sna) via RASM
rasm src/main.asm -o build/handful_of_men -ss -sp

# 7. Run headless regression verification with CPCEmu
cpcemu -headless -sna build/handful_of_men.sna -cycles 5000000 -dump-vram build/vram.dump
```

---

## 6. GAME ARCHITECTURE & CORE SUBSYSTEMS

The codebase must follow a modular layout under `src/`:

```
src/
├── main.asm                 ; Entry point, hardware setup, main game loop
├── crtc/                    ; Screen mode 0 initialization, palette switching
├── render/
│   ├── tilemap.asm          ; Metatile background renderer (Mode 0)
│   ├── sprites.asm          ; Masked sprite software blitter
│   └── vision_cone.asm      ; Dynamic Guard Vision Cone dither/overlay
├── input/
│   ├── keyboard.asm         ; Matrix scanner (hotkeys 1-6, actions, pause)
│   ├── joystick.asm         ; Dual/single joystick driver
│   └── cursor.asm           ; Crosshair/pointer controller
├── entities/
│   ├── commandos.asm        ; Operative status, inventory, coordinate handlers
│   ├── guards.asm           ; Finite State Machine for enemy sentries
│   ├── vehicles.asm         ; Trucks, gunboats, patrol tanks
│   └── items.asm            ; Corpses, explosive barrels, bear traps
├── ai/
│   ├── fsm.asm              ; Patrol -> Investigate -> Alert -> Alarm transitions
│   ├── los.asm              ; Bresenham line-of-sight & obstruction lookup
│   └── sound_grid.asm       ; Noise propagation distance solver
├── audio/
│   ├── psg.asm              ; AY-3-8912 register updater
│   └── sfx.asm              ; Silent knife, gunshot, siren, explosion SFX
├── data/
│   ├── luts.asm             ; Trigonometry tables, screen line address LUT
│   └── palettes.asm         ; Gate Array hardware color definitions
└── missions/
    ├── mission01.asm        ; "Baptism of Fire" (Norway)
    └── mission02.asm        ; "A Quiet Blow-Up"
```

---

## 7. DETAILED SUBSYSTEM SPECIFICATIONS

### 7.1 Mode 0 Tile Engine (`src/render/tilemap.asm`)
* Playfield is built from $8 \times 8$ or $16 \times 16$ pixel metatiles.
* Viewport is framed to maintain 50 Hz / 25 Hz update rates ($128 \times 144$ pixels active playfield, bottom status bar for commando HUD).
* Tiles contain a 1-byte attribute flag: `[BIT 0: Solid/Wall] [BIT 1: Water] [BIT 2: Climbable Cliff] [BIT 3: Snow/Sand (leaves tracks)] [BIT 4: LOS-Opaque]`.

### 7.2 Masked Sprite Blitter (`src/render/sprites.asm`)
* Operatives and guards are $12 \times 16$ Mode 0 pixels ($6 \times 16$ bytes).
* Uses fast masked blitting:
  ```z80
  ; A = Background Byte, B = Sprite Byte, C = Mask Byte
  LD A, (DE)      ; Fetch screen byte
  AND C           ; Clear sprite silhouette via mask
  OR B            ; Splice sprite pixels
  LD (DE), A      ; Write back to screen
  ```
* Supports 8 directional facings ($0^\circ, 45^\circ, 90^\circ, 135^\circ, 180^\circ, 225^\circ, 270^\circ, 315^\circ$).

### 7.3 Vision Cones & Stealth Detection (`src/render/vision_cone.asm` & `src/ai/los.asm`)
* **Inspection Trigger:** Clicking or highlighting a guard displays their vision cone.
* **Dual-Zone Cone Geometry:**
  * **Short Zone (Fatal):** Within 24 pixels, $60^\circ$ arc. Detects crawling commandos, standing commandos, and corpses.
  * **Long Zone (Distal):** 25–64 pixels, $60^\circ$ arc. Detects standing commandos only. Crawling commandos and corpses remain hidden.
* **Line-of-Sight (LOS) Obstruction:** Bresenham raycast against the tile collision matrix (`BIT 4: LOS-Opaque`). If solid terrain intersects, clip the cone sector.
* **Rendering:** Render the cone via a stipple mask (alternating pixels) or ray outline LUTs to minimize Z80 cycles.

### 7.4 Operative Capabilities Matrix (`src/entities/commandos.asm`)
Every operative implements their canonical mechanics:
1. **Green Beret ("Tiny"):**
   * *Combat Knife:* Melee instant kill. Leaves corpse entity.
   * *Radio Decoy:* Deployable entity. Emits radial noise ping (`sound_grid.asm`) when toggled. Lures guards to face and hold for 25 seconds.
   * *Shovel:* Burrows into snow/sand (`BIT 3`); invisible to vision cones until moving.
   * *Body Dragging:* Moves corpses or explosive barrels to clear patrol lanes or prepare sabotage.
2. **Sniper ("Duke"):**
   * *Scoped Rifle:* Ranged instant kill. Ammo strictly counter-limited (3–5 rounds).
   * *First Aid:* Heals wounded operatives.
3. **Marine ("Fins"):**
   * *Scuba Gear:* Enters Water tiles (`BIT 1`); invisible to standard vision cones while submerged.
   * *Harpoon Gun:* Short-range silent kill.
4. **Sapper ("Inferno"):**
   * *Bear Trap:* Placed entity; instantly and silently neutralizes walking patrol guards.
   * *Time Bomb & Remote Detonator:* Timed explosive. Eradicates targets, buildings, and vehicles within a 3-tile blast radius. Triggers general base alarm.
5. **Spy ("Spooky"):**
   * *German Officer Disguise:* Enables walking freely in enemy vision cones without alert.
   * *Distract:* Locks target guard’s facing angle indefinitely while engaged.
   * *Lethal Syringe:* Silent execution.

### 7.5 Guard AI Finite State Machine (`src/ai/fsm.asm`)
Guards execute an autonomous cycle every frame:
* **STATE 0: PATROL:** Follows waypoint sequence $(x_1, y_1) \to (x_2, y_2) \dots$.
* **STATE 1: INVESTIGATE:** Triggered by Decoy, snow footsteps, or distant gunfire. Walks to noise vector, pauses for 10 seconds.
* **STATE 2: SIGHT SUSPICION:** Sights commando in distal vision zone. Exclamation icon `!` appears; delays 1.5 seconds before transitioning to Combat.
* **STATE 3: COMBAT & ALARM:** Raises rifle, fires bursts, and triggers map-wide siren (`SOUND_ALARM`). Nearby idle sentries converge.

---

## 8. MISSION 1 IMPLEMENTATION SPECIFICATION ("Baptism of Fire")
The vertical slice milestone requires complete reproduction of Mission 1:
* **Terrain:** Snow valley, frozen river crossing, guard outpost, security gate, and target radio transmitter tower.
* **Operatives Deployed:** Green Beret, Marine, Sniper.
* **Primary Objective:** Destroy the Radio Transmitter Tower using explosive barrels.
* **Secondary Objective:** Eliminate all outpost sentries without triggering the alarm siren.
* **Extraction:** Board the captured troop truck at the road junction.

---

## 9. INCREMENTAL DEVELOPMENT PLAN FOR THE AI

The AI agent must execute through these explicit engineering milestones:

### Milestone 1: Asset Pipeline & 3D Modeling (Blender MCP & Aseprite MCP)
- [ ] Connect to `blender-mcp`; build low-poly models of Green Beret, German guard, and Mission 1 radio tower.
- [ ] Configure isometric camera with $2:1$ anamorphic aspect ratio compensation.
- [ ] Render 8-direction sprite sheets for idle, walk, crawl, and attack.
- [ ] Connect to `aseprite-mcp`; clamp renders to Amstrad CPC 16-color palette, generate transparency masks, and export sliced sheets.
- [ ] Implement `tools/png2cpc.py` to convert sliced PNGs into Mode 0 interleaved byte streams.

### Milestone 2: Toolchain & Video Hardware Initialization
- [ ] Create directory structure and automated `build.sh` script.
- [ ] Implement `src/crtc/video_init.asm`: Set Mode 0, set Gate Array palette, set screen origin at `&C000`.
- [ ] Assemble test binary with `rasm`, build disk with `idsk`, verify clean boot in `cpcemu`.

### Milestone 3: Tile Engine & Screen Double Buffering
- [ ] Generate Norway snow/metal metatiles via Aseprite MCP.
- [ ] Implement `src/render/tilemap.asm` to draw the $160 \times 144$ tactical area.
- [ ] Add the tactical status GUI bar at screen bottom (showing health, selected item, active commando portrait).

### Milestone 4: Masked Sprite Blitter & Operative Control
- [ ] Implement software cursor with joystick/keyboard control.
- [ ] Write Mode 0 masked sprite blitter supporting 8 orientations.
- [ ] Integrate Green Beret entity with walking, crawling, and knife attack animations.

### Milestone 5: Guard Sight & LOS Raycasting
- [ ] Implement guard patrol pathing with waypoints.
- [ ] Code the 2-zone dynamic vision cone renderer with obstacle raycasting against solid tiles.
- [ ] Implement commando detection logic (standing vs. crawling vs. hiding in snow).

### Milestone 6: Audio & Sound Propagation
- [ ] Implement AY-3-8912 PSG player for SFX (knife stab, decoy chirp, alarm siren, explosion).
- [ ] Integrate noise radius checks so sound triggers guard investigation states.

### Milestone 7: Mission 1 Assembly & Polishing
- [ ] Assemble Mission 1 ("Baptism of Fire") complete with barrels, fences, guards, and radio tower.
- [ ] Implement victory condition (Tower destruction + squad in truck) and defeat conditions (all operatives dead or alarm timer expiration).
- [ ] Build final `.dsk` and `.sna` releases. Run headless automated tests in `cpcemu` to verify 0 CPU crashes and rock-solid 25/50 Hz execution.

---

## 10. CODE QUALITY & HARDWARE CONSTRAINTS
* **Never use illegal Z80 undocumented opcodes** that are unreliable across different Z80 manufacturing revisions (unless proven safe: e.g., standard `IXH`/`IXL` operations).
* **Respect CRTC hardware timings:** Screen register updates and palette alterations must synchronize with VSYNC / HSYNC interrupts to prevent visible tearing.
* **Zero-allocation runtime:** All data structures, entity tables, and buffers must be statically allocated. Dynamic heap allocation is prohibited.
* **All code must compile cleanly:** Zero warnings or errors via `rasm`.
