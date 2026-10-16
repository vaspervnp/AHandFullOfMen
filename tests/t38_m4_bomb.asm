; The Sapper's time bomb at the south end of the rail bridge: down it goes.
TEST equ 1
TEST_MISSION equ 3
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
  ld a,1                        ; Sapper plants it on the tracks by the bank
  call ent_ptr
  ld (ix+ent.x),88
  ld (ix+ent.y),159
  call bomb_key
  ld a,1
  call ent_ptr
  ld (ix+ent.x),18
  ld (ix+ent.y),247
mend
macro SCENARIO
  db 255, 0, &FF
  db 20, 0, &FF
mend
  include "main.asm"
