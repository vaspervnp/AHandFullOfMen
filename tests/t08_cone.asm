; Pointing at a sentry shows its vision cone.
TEST equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.x),70              ; open snow (row 24 col 17)
  ld (ix+ent.y),200
  ld (ix+ent.dir),DIR_NW
  ld (ix+ent.state),ST_IDLE
  ld a,70
  ld (cursor_x),a
  ld a,200-112-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 40, 0, &FF
mend
  include "main.asm"
