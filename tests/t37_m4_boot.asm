; Mission 4 loads: Green Beret, Sapper and Sniper, seven sentries.
TEST equ 1
TEST_MISSION equ 3
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
