; The Green Beret grabs a barrel (G) and drags it west.
TEST equ 1
macro SETUP
  xor a
  call ent_ptr
  ld (ix+ent.x),60
  ld (ix+ent.y),200
  ld (ix+ent.dir),DIR_E
  ld a,9
  call ent_ptr
  ld (ix+ent.x),63
  ld (ix+ent.y),200
  ld a,45
  ld (cursor_x),a
  ld a,200-112-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, 0, KEY_G                ; grab
  db 2, 0, &FF
  db 1, J_F, &FF                ; walk west
  db 40, 0, &FF
mend
  include "main.asm"
