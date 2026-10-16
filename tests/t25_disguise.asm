; The Spy puts the uniform on and stands in front of the gate sentry: unseen.
TEST equ 1
TEST_MISSION equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.dir),DIR_S
  ld a,2
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),98
  ld (ix+ent.y),151
mend
macro SCENARIO
  db 1, 0, KEY_D                     ; uniform on
  db 60, 0, &FF
mend
  include "main.asm"
