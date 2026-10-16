; The Green Beret can't swim: ordered across the river he detours over the
; ice crossing or the bridge.
TEST equ 1
macro SETUP
  ld a,7                        ; river sentry off duty
  call ent_ptr
  ld (ix+ent.type),ET_NONE
  xor a
  call ent_ptr
  ld (ix+ent.x),60
  ld (ix+ent.y),151
  ld a,60
  ld (cursor_x),a
  ld a,119-112
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 200, 0, &FF
mend
  include "main.asm"
