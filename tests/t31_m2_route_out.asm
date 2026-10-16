; From the depot, the Green Beret can reach the truck (sentries removed).
TEST equ 1
TEST_MISSION equ 1
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
  ld a,0
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),98
  ld (ix+ent.y),79
  ld bc,10*256+20
  ld a,TF_SOLID|TF_WATER
  call path_to
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_WALK
mend
macro SCENARIO
  db 255, 0, &FF
  db 200, 0, &FF
mend
  include "main.asm"
