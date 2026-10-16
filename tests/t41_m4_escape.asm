; Mission 4: bridge already down, the Sniper walks into the truck.
TEST equ 1
TEST_MISSION equ 3
macro SETUP
  ld a,1
  ld (target_down),a
  xor a                         ; Green Beret and Sapper fell earlier
  call ent_ptr
  set EF_DEAD,(ix+ent.flags)
  ld a,1
  call ent_ptr
  set EF_DEAD,(ix+ent.flags)
  ld a,2
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),130
  ld (ix+ent.y),40
  ld a,CAM_MAX_X
  ld (cam_x),a
  xor a
  ld (cam_y),a
  ld a,146-CAM_MAX_X*4          ; cursor on the truck
  ld (cursor_x),a
  ld a,20
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 40, 0, &FF
mend
  include "main.asm"
