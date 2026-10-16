; Random play (see tests/fuzz.py): assembled with -DFUZZ=1 -DFUZZ_SEED=n.
; Not a tNN scenario, so run_tests.sh doesn't pick it up.
TEST equ 1
TEST_MENU equ 1                 ; game over / ESC go through the real menu
macro SETUP
mend
macro SCENARIO
mend
  include "main.asm"
