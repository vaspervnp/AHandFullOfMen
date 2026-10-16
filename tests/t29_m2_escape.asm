; Mission 2: depot already down, the Green Beret walks into the truck.
TEST equ 1
TEST_MISSION equ 1
macro SETUP
  ld a,1
  ld (target_down),a
  ld a,1                        ; Sapper and Spy fell earlier
  call ent_ptr
  set EF_DEAD,(ix+ent.flags)
  ld a,2
  call ent_ptr
  set EF_DEAD,(ix+ent.flags)
  xor a                         ; Green Beret on the road below the truck
  call ent_ptr
  ld (ix+ent.x),14
  ld (ix+ent.y),31
  xor a
  ld (cam_x),a
  ld (cam_y),a
  ld a,6                        ; cursor on the truck
  ld (cursor_x),a
  ld a,8
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 40, 0, &FF
mend
  include "main.asm"
