; The Spy walks from the start to the truck through both gates (no sentries).
TEST equ 1
TEST_MISSION equ 6
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
  ld a,2
  ld (sel_cmd),a
  call ent_ptr
  ld bc,138*256+223
  ld a,TF_SOLID|TF_WATER
  call path_to
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_WALK
mend
macro SCENARIO
  db 255, 0, &FF
  db 255, 0, &FF
  db 200, 0, &FF
mend
  include "main.asm"
