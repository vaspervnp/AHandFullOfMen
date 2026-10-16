; The Green Beret drags a barrel from the corner to the plant (no sentries).
TEST equ 1
TEST_MISSION equ 5
macro SETUP
  ld a,3                        ; no sentries: this is about the terrain
.gone:
  push af
  call ent_ptr
  ld (ix+ent.type),ET_NONE
  pop af
  inc a
  cp 10
  jr nz,.gone
  xor a
  call ent_ptr
  ld (ix+ent.x),143
  ld (ix+ent.y),111
  ld (ix+ent.dir),DIR_E
  ld a,16
  ld (cam_x),a
  xor a
  ld (cam_y),a
  ld a,110-16*4                 ; cursor by the plant's door
  ld (cursor_x),a
  ld a,87-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, 0, KEY_G                ; grab
  db 2, 0, &FF
  db 1, J_F, &FF                ; walk to the plant
  db 255, 0, &FF
mend
  include "main.asm"
