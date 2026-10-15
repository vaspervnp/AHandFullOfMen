; Same sentry, but the squad is crawling in the long zone: unseen.
TEST equ 1
macro SETUP
  ld a,3
  call ent_ptr
  ld (ix+ent.x),20
  ld (ix+ent.y),200
  ld (ix+ent.dir),DIR_S
  ld (ix+ent.state),ST_IDLE
  xor a                         ; whole squad crawling
  call ent_ptr
  set EF_CRAWL,(ix+ent.flags)
  ld a,1
  call ent_ptr
  set EF_CRAWL,(ix+ent.flags)
  ld a,2
  call ent_ptr
  set EF_CRAWL,(ix+ent.flags)
mend
macro SCENARIO
  db 70, 0, &FF
mend
  include "main.asm"
