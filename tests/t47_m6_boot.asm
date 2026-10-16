; Mission 6 loads: Green Beret, Sniper and Spy, seven sentries, two barrels.
TEST equ 1
TEST_MISSION equ 5
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
