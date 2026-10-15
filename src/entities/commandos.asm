; ===========================================================================
; Operatives: selection, orders, movement, knife attack
; Entities 0..2 are the commandos (0 Green Beret, 1 Marine, 2 Sniper).
; ===========================================================================

CMD_COUNT       equ 3
CMD_BERET       equ 0
CMD_MARINE      equ 1
CMD_SNIPER      equ 2

KNIFE_RANGE_X   equ 3
KNIFE_RANGE_Y   equ 6
ATTACK_TICKS    equ 8

; Player input -> orders. Called once per game tick.
commandos_input:
  ; 1/2/3 select a commando
  ld a,KEY_1
  call kbd_hit
  ld a,0
  jr nz,.select
  ld a,KEY_2
  call kbd_hit
  ld a,1
  jr nz,.select
  ld a,KEY_3
  call kbd_hit
  ld a,2
  jr nz,.select
  ; D: Green Beret decoy
  ld a,KEY_D
  call kbd_hit
  jp nz,decoy_key
  ; C / fire 2 toggles crawl
  ld a,KEY_C
  call kbd_hit
  jr nz,.crawl
  call joy_fire2_hit
  jr nz,.crawl
  call joy_fire_hit
  ret z
  jr cmd_click
.crawl:
  call sel_ent
  bit EF_DEAD,(ix+ent.flags)
  ret nz
  ld a,(ix+ent.flags)
  xor 1<<EF_CRAWL
  ld (ix+ent.flags),a
  jp hud_mark_dirty
.select:
  call select_cmd
  ret

; A = commando index
select_cmd:
  ld b,a
  ld a,(sel_cmd)
  cp b
  ret z
  ld a,b
  ld (sel_cmd),a
  jp hud_mark_dirty

; Fire pressed: select, attack or move depending on what is under the cursor.
cmd_click:
  call cursor_world
  push bc
  call ent_at
  pop bc
  jr nc,.ground
  cp CMD_COUNT
  jr c,select_cmd               ; clicked a commando
  ld (click_target),a
  ld a,(ix+ent.type)
  cp ET_GUARD
  jr nz,.ground
  ; clicked a guard: the Green Beret goes for the knife
  ld a,(sel_cmd)
  cp CMD_BERET
  jr nz,.ground
  call sel_ent
  bit EF_DEAD,(ix+ent.flags)
  ret nz
  ld a,(click_target)
  inc a
  ld (ix+ent.aux2),a            ; 1 + target entity index
  ld (ix+ent.state),ST_WALK
  ret
.ground:
  call sel_ent
  bit EF_DEAD,(ix+ent.flags)
  ret nz
  push bc
  call map_flags
  pop bc
  and TF_SOLID|TF_WATER
  ret nz                        ; can't walk there
  ld (ix+ent.tx),b
  ld (ix+ent.ty),c
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_WALK
  ret

; Per-tick update for every commando.
commandos_update:
  xor a
.lp:
  push af
  call ent_ptr
  call cmd_update
  pop af
  inc a
  cp CMD_COUNT
  jr nz,.lp
  ret

cmd_update:
  bit EF_DEAD,(ix+ent.flags)
  ret nz
  ld a,(ix+ent.state)
  cp ST_WALK
  jr z,cmd_walk
  cp ST_ATTACK
  jr z,cmd_attack
  ret

cmd_walk:
  ld a,(ix+ent.aux2)
  or a
  jr z,.move
  ; chasing a knife target: aim beside it and strike when close
  dec a
  push ix
  call ent_ptr
  bit EF_DEAD,(ix+ent.flags)
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  pop ix
  jr nz,.lost
  ld (ix+ent.tx),b
  ld (ix+ent.ty),c
  ld a,b
  sub (ix+ent.x)
  add a,KNIFE_RANGE_X
  cp KNIFE_RANGE_X*2+1
  jr nc,.move
  ld a,c
  sub (ix+ent.y)
  add a,KNIFE_RANGE_Y
  cp KNIFE_RANGE_Y*2+1
  jr nc,.move
  ld (ix+ent.state),ST_ATTACK
  ld (ix+ent.timer),ATTACK_TICKS
  ld a,(ix+ent.flags)
  and &FF-(1<<EF_CRAWL)
  ld (ix+ent.flags),a
  jp hud_mark_dirty
.lost:
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_IDLE
  ret
.move:
  ; crawling moves at half speed
  bit EF_CRAWL,(ix+ent.flags)
  jr z,.go
  ld a,(tick)
  and 2
  ret nz
.go:
  ld c,TF_SOLID|TF_WATER
  call ent_step
  jr z,.stop
  inc (ix+ent.anim)
  jp footsteps
.stop:
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.aux2),0
  ret

cmd_attack:
  dec (ix+ent.timer)
  ld a,(ix+ent.timer)
  cp ATTACK_TICKS/2
  jr nz,.wait
  ld a,(ix+ent.aux2)            ; the blow lands halfway through the swing
  dec a
  push ix
  call ent_ptr
  call kill_ent
  pop ix
  ld a,SFX_KNIFE
  call sfx_play
.wait:
  ld a,(ix+ent.timer)
  or a
  ret nz
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.aux2),0
  ret

; IX = entity to kill (leaves a corpse)
kill_ent:
  set EF_DEAD,(ix+ent.flags)
  ld (ix+ent.state),ST_DEAD
  ret
