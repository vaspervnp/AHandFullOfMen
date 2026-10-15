; Alarm raised and the clock runs out: reinforcements, mission failed.
TEST equ 1
macro SETUP
  call alarm_all
  ld a,2
  ld (alarm_secs),a
mend
macro SCENARIO
  db 80, 0, &FF
mend
  include "main.asm"
