; The Sniper shoots a fuel barrel on the pier: the U-boat goes down.
TEST equ 1
TEST_MISSION equ 2
macro SETUP
  ld a,3                        ; sentries stand still facing south
.calm:
  push af
  call ent_ptr
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.dir),DIR_S
  pop af
  inc a
  cp 9
  jr nz,.calm
  ld a,4                        ; the pier guard is at the shore end
  call ent_ptr
  ld (ix+ent.x),90
  ld (ix+ent.y),111
  ld a,1                        ; Sniper at the foot of the pier
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),78
  ld (ix+ent.y),111
  ld (ix+ent.dir),DIR_N
  ld a,8
  ld (cam_x),a
  xor a
  ld (cam_y),a
  ld a,78-8*4                   ; cursor on the barrel
  ld (cursor_x),a
  ld a,63-5
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 40, 0, &FF
mend
  include "main.asm"
