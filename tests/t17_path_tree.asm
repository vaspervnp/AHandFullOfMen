; Click straight behind a pine: the Green Beret walks around it.
TEST equ 1
macro SETUP
  xor a
  call ent_ptr
  ld (ix+ent.x),40              ; col 10 row 25, just south of the trunk
  ld (ix+ent.y),206
  ld a,40                       ; target col 10 row 21, north of the tree
  ld (cursor_x),a
  ld a,172-112
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 70, 0, &FF
mend
  include "main.asm"
