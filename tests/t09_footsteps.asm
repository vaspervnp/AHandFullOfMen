; Walking upright on snow right behind a sentry: he hears the footsteps.
TEST equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.x),40
  ld (ix+ent.y),215
  ld (ix+ent.dir),DIR_N
  ld (ix+ent.state),ST_IDLE
  xor a
  call ent_ptr
  ld (ix+ent.x),38
  ld (ix+ent.y),228
  ld a,48                       ; cursor east of the Green Beret
  ld (cursor_x),a
  ld a,228-112
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF                ; walk east
  db 24, 0, &FF
mend
  include "main.asm"
