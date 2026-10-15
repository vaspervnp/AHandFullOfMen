; Screenshot of the title menu itself (script ends while still on it).
TEST equ 1
TEST_MENU equ 1
macro SETUP
mend
macro SCENARIO
  db 30, 0
mend
  include "main.asm"
