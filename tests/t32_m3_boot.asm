; Mission 3 loads: Marine, Sniper and Spy, six sentries, two pier barrels.
TEST equ 1
TEST_MISSION equ 2
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
