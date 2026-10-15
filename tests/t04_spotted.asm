; A sentry facing the standing Green Beret spots him and raises the alarm.
TEST equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.x),20
  ld (ix+ent.y),200
  ld (ix+ent.dir),DIR_S
  ld (ix+ent.state),ST_IDLE
mend
macro SCENARIO
  db 70, 0
mend
  include "main.asm"
