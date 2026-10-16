; A spot walled in by rocks/trees can't be reached: the order is refused.
TEST equ 1
macro SETUP
  ld hl,map_buf+20*MAP_W+20     ; wall in tile (20,20) with rocks
  ld a,8
  ld (hl),a
  inc hl
  inc hl
  ld (hl),a
  ld hl,map_buf+19*MAP_W+20
  ld (hl),a
  inc hl
  ld (hl),a
  inc hl
  ld (hl),a
  ld hl,map_buf+21*MAP_W+20
  ld (hl),a
  inc hl
  ld (hl),a
  inc hl
  ld (hl),a
  ld a,21*4+2-0                 ; cursor on the enclosed tile (21,20)
  ld (cursor_x),a
  ld a,20*8+4-112
  ld (cursor_y),a
mend
macro SCENARIO
  db 2, 0, &FF
  db 1, J_F, &FF
  db 10, 0, &FF
mend
  include "main.asm"
