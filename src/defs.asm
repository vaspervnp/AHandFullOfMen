; ===========================================================================
; A Handful of Men - global constants
; ===========================================================================

; --- Hardware ports -------------------------------------------------------
GA_PORT         equ &7F         ; Gate Array (B = &7F)
PPI_A           equ &F4         ; PSG data bus
PPI_B           equ &F5         ; bit 0 = VSYNC
PPI_C           equ &F6         ; PSG control (bits 7,6) + keyboard line (bits 3..0)
PPI_CTRL        equ &F7
CRTC_SEL        equ &BC
CRTC_DATA       equ &BD

GA_MODE0_NOROM  equ &8C         ; mode 0, upper+lower ROM disabled
RAM_BASE64      equ &C0         ; default 64K bank configuration
RAM_SPRITES     equ &C4         ; bank 4 at &4000 (beret, guard, cursor, fx)

; --- Screen layout ----------------------------------------------------------
SCREEN          equ &C000
SCR_W           equ 80          ; bytes per scanline
PLAY_H          equ 144         ; tactical area height (lines)
HUD_Y           equ 144         ; first HUD line
VIEW_TW         equ 20          ; visible tiles across
VIEW_TH         equ 18          ; visible tiles down

; --- World ------------------------------------------------------------------
; World coordinates are 8-bit: X in screen-byte units (2 Mode 0 pixels),
; Y in scanlines. One tile = 4 X units x 8 Y units.
MAP_W           equ 40
MAP_H           equ 32
CAM_MAX_X       equ MAP_W-VIEW_TW
CAM_MAX_Y       equ MAP_H-VIEW_TH

; Tile attribute flags (src/data/tileattrs.asm)
TF_SOLID        equ 1
TF_WATER        equ 2
TF_CLIMB        equ 4
TF_SNOW         equ 8
TF_OPAQUE       equ 16

; --- Sprites ----------------------------------------------------------------
SPR_W           equ 6           ; bytes (12 Mode 0 pixels)
SPR_H           equ 16
SPR_SIZE        equ SPR_W*SPR_H*2   ; mask+pixel pairs
CUR_W           equ 4
CUR_H           equ 8
CUR_SIZE        equ CUR_W*CUR_H*2

; Frame numbers inside a character sheet (see tools/renders2sheet.py)
FR_STAND        equ 0
FR_WALK_A       equ 5
FR_WALK_B       equ 10
FR_CRAWL_A      equ 15
FR_CRAWL_B      equ 18
FR_ATTACK       equ 21
FR_CORPSE       equ 24

; Directions (clockwise from north)
DIR_N           equ 0
DIR_NE          equ 1
DIR_E           equ 2
DIR_SE          equ 3
DIR_S           equ 4
DIR_SW          equ 5
DIR_W           equ 6
DIR_NW          equ 7

; --- Entities ---------------------------------------------------------------
MAX_ENTS        equ 16
ET_NONE         equ 0
ET_COMMANDO     equ 1
ET_GUARD        equ 2
ET_DECOY        equ 3
ET_BARREL       equ 4
ET_FX           equ 5           ; explosion animation

struct ent
type    defb 0
x       defb 0          ; feet position, world X units
y       defb 0          ; feet position, world lines
dir     defb 0
anim    defb 0          ; animation counter
state   defb 0
tx      defb 0          ; movement target
ty      defb 0
flags   defb 0
gfx     defw 0          ; sprite sheet base
aux     defb 0          ; waypoint index / commando id
aux2    defb 0
timer   defb 0
hp      defb 0          ; commando health (0..8)
idx     defb 0          ; own entity index
ai      defb 0          ; guard AI state (AI_*)
ai_timer defb 0
ai_seen defb 0          ; entity index the guard is reacting to
fire    defb 0          ; guard shot cooldown
sbank   defb 0          ; RAM config holding the sprite sheet (&C4/&C5)
drag    defb 0          ; 1 + index of the entity being dragged
fuse    defb 0          ; barrel chain-reaction countdown
pad     defs 9
endstruct
ENT_SIZE        equ {sizeof}ent
  assert ENT_SIZE==32

; ent.flags
EF_CRAWL        equ 0           ; bit numbers
EF_MOVING       equ 1
EF_DEAD         equ 2
EF_SELECTED     equ 3
EF_BOARDED      equ 4           ; commando is in the escape truck

; Entity states
ST_IDLE         equ 0
ST_WALK         equ 1
ST_ATTACK       equ 2
ST_DEAD         equ 3

; Guard AI states (src/ai/fsm.asm)
AI_PATROL       equ 0
AI_INVESTIGATE  equ 1
AI_SUSPICIOUS   equ 2
AI_ALARM        equ 3

; --- Keyboard matrix (line, bit) --------------------------------------------
KEY_UP          equ &00         ; cursor up     line 0 bit 0
KEY_RIGHT       equ &01
KEY_DOWN        equ &02
KEY_LEFT        equ &10         ; line 1 bit 0
KEY_COPY        equ &11
KEY_RETURN      equ &22
KEY_P           equ &33
KEY_O           equ &42
KEY_K           equ &45
KEY_SPACE       equ &57
KEY_V           equ &67
KEY_C           equ &76
KEY_D           equ &75
KEY_G           equ &64
KEY_1           equ &80
KEY_2           equ &81
KEY_ESC         equ &82
KEY_Q           equ &83
KEY_A           equ &85
KEY_3           equ &71
KEY_JUP         equ &90
KEY_JDOWN       equ &91
KEY_JLEFT       equ &92
KEY_JRIGHT      equ &93
KEY_JFIRE2      equ &94
KEY_JFIRE1      equ &95
