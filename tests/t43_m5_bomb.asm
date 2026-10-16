; The Sapper's time bomb at the foot of the coastal gun: the battery goes up.
TEST equ 1
TEST_MISSION equ 4
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
  ld a,1                        ; Sapper plants it just south of the pit
  call ent_ptr
  ld (ix+ent.x),62
  ld (ix+ent.y),95
  call bomb_key
  ld a,1
  call ent_ptr
  ld (ix+ent.x),46
  ld (ix+ent.y),247
mend
macro SCENARIO
  db 255, 0, &FF
  db 20, 0, &FF
mend
  include "main.asm"
