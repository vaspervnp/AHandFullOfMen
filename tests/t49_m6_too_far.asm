; The barrel shot where it stands: too far, the plant survives.
TEST equ 1
TEST_MISSION equ 5
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
  ld a,10                       ; the barrel
  call ent_ptr
  ld (ix+ent.x),146
  ld (ix+ent.y),111
  ld a,1                        ; Sniper inside the gate
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),110
  ld (ix+ent.y),111
  ld (ix+ent.dir),DIR_N
  ld a,16
  ld (cam_x),a
  xor a
  ld (cam_y),a
  ld a,146-16*4                  ; cursor on the barrel
  ld (cursor_x),a
  ld a,111-5
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 60, 0, &FF
mend
  include "main.asm"
