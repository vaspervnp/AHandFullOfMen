; ===========================================================================
; Role abilities on keys D and G, and the Sapper's devices
;   Green Beret  D radio decoy        G drag a barrel or body
;   Sapper       D bear trap (2)      G time bomb (1): 10 s fuse, wide blast
;   Spy          D German uniform     G distract the sentry next to him
; The Spy's syringe is his attack (same reach as the knife, silent).
; ===========================================================================

TRAP_COUNT      equ 2
BOMB_COUNT      equ 1
BOMB_TICKS      equ 250         ; 10 s
BOMB_R          equ 48          ; visual units: 3 tiles across
TRAP_REACH_X    equ 2           ; a walking sentry this close springs it
TRAP_REACH_Y    equ 5
DISTRACT_X      equ 6           ; how close the Spy must be to start talking
DISTRACT_Y      equ 12
DISTRACT_KEEP   equ 24          ; the sentry loses interest beyond this

ability_d:
  call sel_ent
  call cmd_can_act
  ret nz
  ld a,(ix+ent.role)
  cp ROLE_BERET
  jp z,decoy_key
  cp ROLE_SAPPER
  jp z,trap_key
  cp ROLE_SPY
  jp z,disguise_key
  ret

ability_g:
  call sel_ent
  call cmd_can_act
  ret nz
  ld a,(ix+ent.role)
  cp ROLE_BERET
  jp z,drag_key
  cp ROLE_SAPPER
  jp z,bomb_key
  cp ROLE_SPY
  jp z,distract_key
  ret

; ---------------------------------------------------------------------------
; Sapper
; ---------------------------------------------------------------------------
trap_key:
  ld hl,traps
  ld a,(hl)
  or a
  ret z
  dec (hl)
  ld c,ET_TRAP
  call place_device
  jp hud_mark_dirty

bomb_key:
  ld hl,bombs
  ld a,(hl)
  or a
  ret z
  dec (hl)
  ld c,ET_BOMB
  call place_device
  ret nc
  ld (ix+ent.fuse),BOMB_TICKS
  jp hud_mark_dirty

; IX = Sapper, C = device type: put it down at his feet.
; -> carry, IX = the device (NC: no free entity slot)
place_device:
  ld b,(ix+ent.x)
  ld e,(ix+ent.y)
  push bc
  push de
  call ent_alloc
  pop de
  pop bc
  ret nc
  ld (ix+ent.type),c
  ld (ix+ent.x),b
  ld (ix+ent.y),e
  ld (ix+ent.dir),DIR_S
  ld (ix+ent.gfx),spr_fx and &FF
  ld (ix+ent.gfx+1),spr_fx>>8
  ld (ix+ent.sbank),RAM_SPRITES
  scf
  ret

; A free entity slot after the squad (the decoy has its own).
; -> carry, A = index, IX = the cleared entity
ent_alloc:
  ld a,CMD_COUNT
.lp:
  call ent_ptr
  ld b,a
  ld a,(ix+ent.type)
  or a
  ld a,b
  jr z,.found
  inc a
  cp DECOY_ENT
  jr nz,.lp
  or a
  ret
.found:
  push ix
  pop hl
  ld d,h
  ld e,l
  inc de
  ld (hl),0
  ld bc,ENT_SIZE-1
  ldir
  ld (ix+ent.idx),a
  scf
  ret

; IX = bear trap (from items_update): a sentry walking onto it dies, silently.
trap_update:
  ld iy,ent_table+GUARD_FIRST*ENT_SIZE
  ld b,MAX_ENTS-GUARD_FIRST
.lp:
  ld a,(iy+ent.type)
  cp ET_GUARD
  jr nz,.next
  bit EF_DEAD,(iy+ent.flags)
  jr nz,.next
  ld a,(iy+ent.state)
  cp ST_WALK
  jr nz,.next
  ld a,(iy+ent.x)
  sub (ix+ent.x)
  add a,TRAP_REACH_X
  cp TRAP_REACH_X*2+1
  jr nc,.next
  ld a,(iy+ent.y)
  sub (ix+ent.y)
  add a,TRAP_REACH_Y
  cp TRAP_REACH_Y*2+1
  jr c,.snap
.next:
  ld de,ENT_SIZE
  add iy,de
  djnz .lp
  ret
.snap:
  ld (ix+ent.type),ET_NONE      ; sprung: gone
  ld a,SFX_KNIFE
  call sfx_play
  push iy
  pop ix
  ld (ix+ent.hp),0
  jp kill_ent

; ---------------------------------------------------------------------------
; Spy
; ---------------------------------------------------------------------------
; IX = Spy: put the German uniform on or take it off.
disguise_key:
  ld a,(ix+ent.flags)
  xor 1<<EF_DISGUISE
  ld (ix+ent.flags),a
  and 1<<EF_DISGUISE
  ld hl,spr_spy
  ld a,RAM_BANK6
  jr z,.look
  ld hl,spr_guard               ; looks just like a sentry
  ld a,RAM_SPRITES
.look:
  ld (ix+ent.gfx),l
  ld (ix+ent.gfx+1),h
  ld (ix+ent.sbank),a
  jp hud_mark_dirty

; IX = Spy (in uniform): the sentry next to him turns to talk and forgets
; about everything else he would be watching.
distract_key:
  bit EF_DISGUISE,(ix+ent.flags)
  ret z
  ld iy,ent_table+GUARD_FIRST*ENT_SIZE
  ld b,MAX_ENTS-GUARD_FIRST
.lp:
  ld a,(iy+ent.type)
  cp ET_GUARD
  jr nz,.next
  bit EF_DEAD,(iy+ent.flags)
  jr nz,.next
  ld a,(iy+ent.ai)
  cp AI_ALARM
  jr z,.next
  ld a,(iy+ent.x)
  sub (ix+ent.x)
  add a,DISTRACT_X
  cp DISTRACT_X*2+1
  jr nc,.next
  ld a,(iy+ent.y)
  sub (ix+ent.y)
  add a,DISTRACT_Y
  cp DISTRACT_Y*2+1
  jr c,.talk
.next:
  ld de,ENT_SIZE
  add iy,de
  djnz .lp
  ret
.talk:
  ld (iy+ent.ai),AI_DISTRACTED
  ld a,(ix+ent.idx)
  ld (iy+ent.ai_seen),a
  ld (iy+ent.state),ST_IDLE
  ld (iy+ent.anim),0
  push ix
  push iy
  pop ix
  call face_target
  pop ix
  ret

; IX = distracted guard (from ai_update): face the Spy while he stays close
; and in uniform; still notices anything else in front of him.
ai_do_distracted:
  ld a,(ix+ent.ai_seen)
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  ld a,(iy+ent.flags)
  and (1<<EF_DEAD)|(1<<EF_BOARDED)
  jp nz,ai_resume_patrol
  bit EF_DISGUISE,(iy+ent.flags)
  jp z,ai_resume_patrol
  call vis_vector
  jp c,ai_resume_patrol
  call vis_distance
  cp DISTRACT_KEEP+1
  jp nc,ai_resume_patrol
  call face_target
  call guard_look
  ret nc
  jp ai_spotted
