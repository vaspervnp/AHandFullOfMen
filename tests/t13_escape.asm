; Tower already down, last survivor walks into the truck: mission accomplished.
TEST equ 1
macro SETUP
  ld a,1
  ld (tower_down),a
  ld a,1                        ; Marine and Sniper fell earlier
  call ent_ptr
  set EF_DEAD,(ix+ent.flags)
  ld a,2
  call ent_ptr
  set EF_DEAD,(ix+ent.flags)
  xor a
  call ent_ptr
  ld (ix+ent.x),130
  ld (ix+ent.y),224
  ld a,CAM_MAX_X
  ld (cam_x),a
  ld a,146-CAM_MAX_X*4          ; cursor on the truck
  ld (cursor_x),a
  ld a,224-CAM_MAX_Y*8
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 30, 0, &FF
mend
  include "main.asm"
