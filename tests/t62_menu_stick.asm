; The stick steps through the menu: right picks Mission 2, left twice wraps
; round to the training, Fire starts it.
TEST equ 1
TEST_MENU equ 1
macro SETUP
mend
macro SCENARIO
  db 10, 0, &FF
  db 2, J_R, &FF
  db 6, 0, &FF
  db 2, J_L, &FF
  db 6, 0, &FF
  db 2, J_L, &FF
  db 10, 0, &FF
  db 1, J_F, &FF
  db 10, 0, &FF                      ; briefing
  db 1, J_F, &FF
  db 20, 0, &FF
mend
  include "main.asm"
