; The Marine swims up the coast and in through the gap (sentries removed).
TEST equ 1
TEST_MISSION equ 4
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
  ld (sel_cmd),a
  call ent_ptr
  ld bc,50*256+63
  ld a,TF_SOLID
  call path_to
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_WALK
mend
macro SCENARIO
  db 255, 0, &FF
  db 255, 0, &FF
mend
  include "main.asm"
