; Click above the Green Beret: he should walk north.
TEST equ 1
macro SCENARIO
  db 4, 0, &FF           ; settle
  db 6, J_U, &FF         ; cursor up
  db 2, J_F, &FF         ; click: move order
  db 60, 0, &FF          ; walk
mend
macro SETUP
mend
  include "main.asm"
