; Mission 3: U-boat already sunk, the Marine walks into the truck.
TEST equ 1
TEST_MISSION equ 2
macro SETUP
  ld a,1
  ld (target_down),a
  ld a,1                        ; Sniper and Spy fell earlier
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
