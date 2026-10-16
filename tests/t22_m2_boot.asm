; Mission 2 loads: Green Beret, Sapper and Spy, seven sentries, the depot.
TEST equ 1
TEST_MISSION equ 1
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
