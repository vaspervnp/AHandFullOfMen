; The Green Beret pings a decoy: a sentry walks over and stays there.
TEST equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.x),40
  ld (ix+ent.y),150
  ld (ix+ent.dir),DIR_N
  ld (ix+ent.state),ST_IDLE
  ld b,50                       ; decoy already dropped here
  ld c,170
  call decoy_place
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, 0, KEY_D                ; ping
  db 50, 0, &FF
mend
  include "main.asm"
