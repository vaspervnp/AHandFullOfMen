; V pins the river sentry's cone; it follows him along his patrol.
TEST equ 1
macro SETUP
  ld a,18                       ; cursor on the river guard (entity 7)
  ld (cursor_x),a
  ld a,119-112-6
  ld (cursor_y),a
mend
macro SCENARIO
  db 1, 0, KEY_V
  db 90, 0, &FF
mend
  include "main.asm"
