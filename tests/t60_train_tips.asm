; Training: the Green Beret in the middle of the camp gets the cone tip.
TEST equ 1
TEST_MISSION equ 7
macro SETUP
  ld a,3                        ; sentries stand still facing north
.calm:
  push af
  call ent_ptr
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.dir),DIR_N
  pop af
  inc a
  cp 5
  jr nz,.calm
  xor a
  call ent_ptr
  ld (ix+ent.x),30
  ld (ix+ent.y),119
  ld a,0
  ld (cam_x),a
  ld a,6
  ld (cam_y),a
mend
macro SCENARIO
  db 10, 0, &FF
mend
  include "main.asm"
