; Green Beret sneaks up behind a sentry and uses the knife.
TEST equ 1
macro SETUP
  ld a,3                        ; bridge guard: standing still, facing away
  call ent_ptr
  ld (ix+ent.x),26
  ld (ix+ent.y),215
  ld (ix+ent.dir),DIR_N
  ld (ix+ent.state),ST_IDLE
  ld a,26                       ; cursor on the guard (cam_x = 0, cam_y = 14)
  ld (cursor_x),a
  ld a,215-112-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 3, 0, &FF
  db 1, J_F, &FF                     ; click the guard: knife order
  db 50, 0, &FF
mend
  include "main.asm"
