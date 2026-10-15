; Title menu renders with the shortcut list, then Fire starts the mission.
TEST equ 1
TEST_MENU equ 1
macro SETUP
mend
macro SCENARIO
  db 20, 0, &FF                      ; look at the menu
  db 1, J_F, &FF                     ; start
  db 20, 0, &FF                      ; in the mission
mend
  include "main.asm"
