; The Spy creeps up behind the bridge sentry: syringe, silent kill.
TEST equ 1
TEST_MISSION equ 1
macro SETUP
  ld a,4                        ; bridge sentry stands still facing east
  call ent_ptr
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.dir),DIR_E
  ld a,2
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),6
  ld (ix+ent.y),127
  ld a,14                       ; cursor on the sentry (cam 0,14)
  ld (cursor_x),a
  ld a,127-112-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 3, 0, &FF
  db 1, J_F, &FF
  db 50, 0, &FF
mend
  include "main.asm"
