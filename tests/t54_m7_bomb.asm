; The Sapper's time bomb beside the wagons: the train goes up.
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
  ld a,1                        ; Sapper plants it south of the train
  call ent_ptr
  ld (ix+ent.x),78
  ld (ix+ent.y),127
  call bomb_key
  ld a,1
  call ent_ptr
  ld (ix+ent.x),14
  ld (ix+ent.y),23
mend
macro SCENARIO
  db 255, 0, &FF
  db 20, 0, &FF
mend
  include "main.asm"
