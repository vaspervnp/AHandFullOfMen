; Training loads: Beret, Marine, Sniper, two sentries, the first tip shown.
TEST equ 1
TEST_MISSION equ 7
macro SETUP
mend
macro SCENARIO
  db 30, 0, &FF
mend
  include "main.asm"
