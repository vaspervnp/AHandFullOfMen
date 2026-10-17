; Mission 7 loads: Sniper, Sapper and Spy, seven sentries, three barrels.
TEST equ 1
TEST_MISSION equ 6
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
