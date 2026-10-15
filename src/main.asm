; ===========================================================================
; A HANDFUL OF MEN - Amstrad CPC 6128
; Entry point, hardware setup and main game loop.
;
; Memory map
;   &0040-&3FFF  code, tables, variables, stack (grows down from &4000)
;   &4000-&7FFF  tiles, font, portraits, mission data, live map
;                (paged out for RAM bank 4 = sprite sheets while blitting)
;   &8000-&BFFF  screen buffer B
;   &C000-&FFFF  screen buffer A
;
; Outputs (paths relative to the build directory):
;   code.bin  -> &0040     data.bin -> &4000
;   sprites.bin -> bank 4  sprites2.bin -> bank 5
;   handful.sna (when not TEST)
; ===========================================================================

  include "defs.asm"

  ifndef TEST
TEST equ 0
  endif
  ifndef TEST_MENU
TEST_MENU equ 0                 ; test scenarios skip the menu unless set
  endif

  buildsna
  bankset 0
  run start

  org &0040
start:
  di
  ld sp,&4000
  im 1
  ld a,&C3                      ; JP int_handler at the IM 1 vector
  ld (&0038),a
  ld hl,int_handler
  ld (&0039),hl
  ld bc,&7F00+RAM_BASE64
  out (c),c
  call video_init               ; mode 0, black palette, screens cleared
  call psg_init
  ei

title:
  if TEST_MENU || (TEST==0)
  call menu_run
  endif
mission_start:
  call palette_black
  ld a,&C0
  ld (back_hi),a
  ld hl,m01_spawns
  ld de,map_mission01
  ld bc,M01_CAM_X*256+M01_CAM_Y
  call mission_load
  if TEST
  call test_setup
  endif
  ; draw both buffers before showing anything
  call render_frame
  call flip
  call render_frame
  call flip
  ld hl,pal_norway
  call palette_set

main_loop:
  call wait_frame
  call kbd_scan
  call joy_read
  if TEST
  call test_input
  endif
  ld a,KEY_ESC
  call kbd_hit
  jr z,.play
  call psg_init                 ; silence the siren
  jp title
.play:
  call cursor_update
  ld a,(game_over)
  or a
  jr nz,.over
  call commandos_input
  call commandos_update
  call guards_update
  call items_update
  call check_end
  call clock_update
  jr .live
.over:
  ld hl,end_timer               ; let the last moment sink in, then debrief
  dec (hl)
  jr nz,.live
  call debrief_run
  jp title
.live:
  call update_cursor_frame
  call cone_update
  call sfx_update
  ld hl,tick
  inc (hl)
  call render_frame
  call flip
  jr main_loop

  if TEST
; Scripted input for headless regression tests: (ticks, joy_state, key)
; from the scenario's SCENARIO macro (tests/tNN_*.asm). When the script
; runs out we jump to &0000, where CAP32_WAITBREAK / cpcsim stop.
test_input:
  ld hl,(test_ptr)
  ld a,(hl)
  or a
  jp z,0
  inc hl
  ld a,(hl)
  ld (joy_state),a
  inc hl
  ld a,(hl)                     ; key held during this step, &FF = none
  cp &FF
  call nz,test_press
  ld hl,test_count
  inc (hl)
  ld a,(hl)
  ld hl,(test_ptr)
  cp (hl)
  ret nz
  xor a
  ld (test_count),a
  inc hl
  inc hl
  inc hl
  ld (test_ptr),hl
  ret
; A = key code: clear its bit in the freshly scanned matrix
test_press:
  ld c,a
  rrca
  rrca
  rrca
  rrca
  and &0F
  ld hl,keymap
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld a,c
  and 7
  ld b,a
  ld a,&FE
  jr z,.clr
.rot:
  rlca
  djnz .rot
.clr:
  and (hl)
  ld (hl),a
  ret
test_ptr: dw test_script
test_count: db 0
J_U equ 1<<JOY_UP
J_D equ 1<<JOY_DOWN
J_L equ 1<<JOY_LEFT
J_R equ 1<<JOY_RIGHT
J_F equ 1<<JOY_FIRE
J_F2 equ 1<<JOY_FIRE2
test_script:
  SCENARIO                      ; macro defined by the test scenario
  db 0
; Scenario staging after mission_load (macro SETUP: place entities, cursor)
test_setup:
  SETUP
  ret
  endif

  include "crtc/video_init.asm"
  include "input/keyboard.asm"
  include "input/joystick.asm"
  include "input/cursor.asm"
  include "render/tilemap.asm"
  include "render/sprites.asm"
  include "render/render.asm"
  include "render/hud.asm"
  include "render/vision_cone.asm"
  include "entities/entities.asm"
  include "entities/commandos.asm"
  include "entities/guards.asm"
  include "entities/items.asm"
  include "ai/los.asm"
  include "ai/fsm.asm"
  include "ai/sound_grid.asm"
  include "audio/psg.asm"
  include "audio/sfx.asm"
  include "game.asm"
  include "menu.asm"
  include "data/luts.asm"
  include "data/palettes.asm"
  include "data/tileattrs.asm"
  include "missions/mission01.asm"

; ---------------------------------------------------------------------------
; Variables (static, zero-initialised in the binary)
; ---------------------------------------------------------------------------
vars_start:
vsync_count:    db 0
last_vsync:     db 0
tick:           db 0
back_hi:        db &C0
view_dirty:     db 0
hud_dirty:      db 0
cam_x:          db 0
cam_y:          db 0
cursor_x:       db 0
cursor_y:       db 0
cur_hold:       db 0
cursor_frame:   db 0
joy_state:      db 0
joy_prev:       db 0
keymap:         defs 10,&FF
keymap_prev:    defs 10,&FF
sel_cmd:        db 0
alarm:          db 0
game_over:      db 0           ; 0 playing, 1 failed, 2 accomplished
end_reason:     db 0
end_timer:      db 0
tower_down:     db 0
ammo:           db 0
click_type:     db 0
alarm_secs:     db 0
sec_ticks:      db 0
mission_secs:   dw 0
num_buf:        defs 6
deb_result_ink: db 0
deb_result_ptr: dw 0
deb_reason_ptr: dw 0
page_prompt:    dw 0
page_prompt_row: db 0
click_target:   db 0
ent_scan:       db 0
step_block:     db 0
look_idx:       db 0
look_r:         db 0
siren_phase:    db 0
sfx_ptr:        dw 0
vis_vx:         db 0
vis_vy:         db 0
vis_ax:         db 0
vis_ay:         db 0
los_x:          dw 0
los_y:          dw 0
los_dx:         dw 0
los_dy:         dw 0
bl_src:         dw 0
bl_fullw:       db 0
cur_dirty:      dw 0
hp_idx:         db 0
hp_x:           db 0
hp_frame:       db 0
hp_hp:          db 0
text_pairs:     defs 4
text_paper:     db PEN_HUD
menu_blink:     db 0
hud_bg:         db 0
cone_guard:     db CONE_NONE
cone_pinned:    db CONE_NONE
cone_key:       defs 6,&FF
cone_step:      db 0
cone_tiles:     defs DIRTY_SIZE
cone_count:     db 0
cone_ang:       db 0
cone_cx:        db 0
cone_cy:        db 0
cone_wr:        dw 0
cone_dx:        dw 0
cone_dy:        dw 0
cone_fx:        dw 0
cone_fy:        dw 0
cone_buf:       defs CONE_RAYS*CONE_STEPS*3
noise_x:        db 0
noise_y:        db 0
noise_r:        db 0
noise_t:        db 0
draw_count:     db 0
draw_list:      defs MAX_ENTS
ent_route:      defs MAX_ENTS*2
dirty_c0:       defs DIRTY_SIZE
dirty_80:       defs DIRTY_SIZE
ent_table:      defs MAX_ENTS*ENT_SIZE
code_end:
  assert code_end<&3C00         ; leave 1K for the stack

; ---------------------------------------------------------------------------
; Base RAM &4000: graphics and mission data
; ---------------------------------------------------------------------------
  org &4000
data_start:
  include "tiles.asm"           ; generated: build/tiles.asm
  include "ui.asm"              ; generated: build/ui.asm
  include "mission01_map.asm"   ; generated: build/mission01_map.asm
map_buf:        defs MAP_W*MAP_H
data_end:
  assert data_end<=&8000

  if TEST==0
  save "code.bin",&0040,code_end-&0040
  save "data.bin",data_start,data_end-data_start
  endif

; ---------------------------------------------------------------------------
; RAM bank 4 (paged at &4000): sprite sheets
; ---------------------------------------------------------------------------
  bank 4
  org &4000
sprites_start:
  include "sprites.asm"         ; generated: build/sprites.asm
sprites_end:
  assert sprites_end<=&8000

  if TEST==0
  save "sprites.bin",sprites_start,sprites_end-sprites_start
  endif

; ---------------------------------------------------------------------------
; RAM bank 5 (paged at &4000): Marine and Sniper sheets
; ---------------------------------------------------------------------------
  bank 5
  org &4000
sprites2_start:
  include "sprites2.asm"        ; generated: build/sprites2.asm
sprites2_end:
  assert sprites2_end<=&8000

  if TEST==0
  save "sprites2.bin",sprites2_start,sprites2_end-sprites2_start
  endif
