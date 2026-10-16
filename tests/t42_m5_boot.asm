; Mission 5 loads: Marine, Sapper and Spy, seven sentries.
TEST equ 1
TEST_MISSION equ 4
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
