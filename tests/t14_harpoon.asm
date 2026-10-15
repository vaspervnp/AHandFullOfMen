; The Marine harpoons a sentry from a few metres: silent kill.
TEST equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.x),70
  ld (ix+ent.y),200
  ld (ix+ent.dir),DIR_N
  ld (ix+ent.state),ST_IDLE
  ld a,1
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),70
  ld (ix+ent.y),226
  ld a,70
  ld (cursor_x),a
  ld a,200-112-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 20, 0, &FF
mend
  include "main.asm"
