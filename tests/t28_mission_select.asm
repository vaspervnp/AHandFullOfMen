; Key 2 on the title menu picks Mission 2, Fire starts it.
TEST equ 1
TEST_MENU equ 1
macro SETUP
mend
macro SCENARIO
  db 10, 0, &FF
  db 1, 0, KEY_2
  db 10, 0, &FF
  db 1, J_F, &FF
  db 10, 0, &FF                      ; briefing
  db 1, J_F, &FF
  db 20, 0, &FF
mend
  include "main.asm"
