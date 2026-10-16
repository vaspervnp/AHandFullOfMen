; The Spy in uniform talks to the gate sentry, who turns and stays put.
TEST equ 1
TEST_MISSION equ 1
macro SETUP
  ld a,2
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),102
  ld (ix+ent.y),135
  call disguise_key
mend
macro SCENARIO
  db 1, 0, KEY_G                     ; talk
  db 60, 0, &FF
mend
  include "main.asm"
