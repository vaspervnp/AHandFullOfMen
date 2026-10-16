; The Sapper's bear trap on the river path: the sentry walks into it.
TEST equ 1
TEST_MISSION equ 1
macro SETUP
  ld a,1                        ; Sapper sets it at (50,175), then is back
  call ent_ptr                  ; at the start before anyone looks
  ld (ix+ent.x),50
  ld (ix+ent.y),175
  call trap_key
  ld a,1
  call ent_ptr
  ld (ix+ent.x),18
  ld (ix+ent.y),247
mend
macro SCENARIO
  db 150, 0, &FF                     ; the river guard paces 26..70
mend
  include "main.asm"
