; The Sniper shoots the barrel beside the train: it takes the train with it.
TEST equ 1
TEST_MISSION equ 6
macro SETUP
  ld a,3                        ; sentries stand still facing north
.calm:
  push af
  call ent_ptr
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.dir),DIR_N
  pop af
  inc a
  cp 10
  jr nz,.calm
  xor a                         ; Sniper north of the line, looking south
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),102
  ld (ix+ent.y),71
  ld (ix+ent.dir),DIR_S
  ld a,10
  ld (cam_x),a
  xor a
  ld (cam_y),a
  ld a,74-10*4                  ; cursor on the barrel
  ld (cursor_x),a
  ld a,87-5
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 60, 0, &FF
mend
  include "main.asm"
