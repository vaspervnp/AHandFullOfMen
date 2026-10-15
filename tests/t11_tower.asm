; The Sniper shoots a barrel next to the radio tower: tower down, alarm up.
TEST equ 1
macro SETUP
  ld a,3                        ; all sentries stand still facing north
.calm:
  push af
  call ent_ptr
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.dir),DIR_N
  pop af
  inc a
  cp 8
  jr nz,.calm
  ld a,8                        ; compound barrel dragged next to the tower
  call ent_ptr
  ld (ix+ent.x),147
  ld (ix+ent.y),60
  ld a,2                        ; Sniper in the compound with a clear shot
  ld (sel_cmd),a
  call ent_ptr
  ld (ix+ent.x),150
  ld (ix+ent.y),95
  ld (ix+ent.dir),DIR_N
  ld a,CAM_MAX_X
  ld (cam_x),a
  xor a
  ld (cam_y),a
  ld a,147-CAM_MAX_X*4          ; cursor on the barrel
  ld (cursor_x),a
  ld a,60-5
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF                ; fire at the barrel
  db 40, 0, &FF
mend
  include "main.asm"
