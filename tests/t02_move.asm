; Click above the Green Beret: he should walk north.
TEST equ 1
macro SCENARIO
  db 4, 0           ; settle
  db 6, J_U         ; cursor up
  db 2, J_F         ; click: move order
  db 60, 0          ; walk
mend
macro SETUP
mend
  include "main.asm"
