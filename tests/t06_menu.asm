; Title menu renders with the shortcut list, then Fire starts the mission.
TEST equ 1
TEST_MENU equ 1
macro SETUP
mend
macro SCENARIO
  db 20, 0                      ; look at the menu
  db 1, J_F                     ; start
  db 20, 0                      ; in the mission
mend
  include "main.asm"
