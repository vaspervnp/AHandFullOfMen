; The Marine takes the direct route straight through the water.
TEST equ 1
macro SETUP
  ld a,7
  call ent_ptr
  ld (ix+ent.type),ET_NONE
  ld a,1
  ld (sel_cmd),a
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
  db 24, 0, &FF
mend
  include "main.asm"
