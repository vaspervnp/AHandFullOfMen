; Boot: mission loads, both buffers render, HUD shows. Idle 40 ticks.
TEST equ 1
macro SCENARIO
  db 40, 0
mend
macro SETUP
mend
  include "main.asm"
