; ===========================================================================
; Operatives: selection, orders, movement, attacks, boarding the truck
; Entities 0..2 are the commandos:
;   0 Green Beret "Tiny"  knife (melee), radio decoy, drags barrels/bodies
;   1 Marine      "Fins"  swims (hidden underwater), harpoon (short range)
;   2 Sniper      "Duke"  rifle (long range, needs line of sight, 5 rounds)
; ===========================================================================

CMD_COUNT       equ 3
CMD_BERET       equ 0
CMD_MARINE      equ 1
CMD_SNIPER      equ 2

KNIFE_RANGE_X   equ 3
KNIFE_RANGE_Y   equ 6
HARPOON_RANGE   equ 36          ; visual units
RIFLE_RANGE     equ 112
RIFLE_AMMO      equ 5
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
  ld a,KEY_D
  call kbd_hit
  jp nz,decoy_key
  ld a,KEY_G
  call kbd_hit
  jp nz,drag_key
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
  call cmd_can_act
  ret nz
  ld a,(ix+ent.drag)            ; can't crawl while dragging
  or a
  ret nz
  ld a,(ix+ent.flags)
  xor 1<<EF_CRAWL
  ld (ix+ent.flags),a
  jp hud_mark_dirty
.select:
  jp select_cmd

; IX = commando -> Z if it can take orders (alive, not in the truck)
cmd_can_act:
  ld a,(ix+ent.flags)
  and (1<<EF_DEAD)|(1<<EF_BOARDED)
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
  ld (click_type),a
  call sel_ent
  call cmd_can_act
  ret nz
  call cmd_can_attack
  jr nc,.ground
  ld a,(click_target)
  inc a
  ld (ix+ent.aux2),a            ; 1 + target entity index
  ld (ix+ent.state),ST_WALK
  ret
.ground:
  call sel_ent
  call cmd_can_act
  ret nz
  push bc
  call map_flags
  pop bc
  ld e,a
  call cmd_block_flags
  and e
  ret nz                        ; can't walk there
  ld (ix+ent.tx),b
  ld (ix+ent.ty),c
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_WALK
  ret

; IX = selected commando, (click_type) = target type
; -> carry if this commando can attack that target
cmd_can_attack:
  ld a,(ix+ent.drag)            ; hands full
  or a
  jr nz,.no
  ld a,(click_type)
  cp ET_GUARD
  jr z,.guard
  cp ET_BARREL
  jr nz,.no
  ld a,(ix+ent.idx)             ; only a bullet sets off a barrel
  cp CMD_SNIPER
  jr nz,.no
.guard:
  ld a,(ix+ent.idx)
  cp CMD_SNIPER
  jr nz,.yes
  ld a,(ammo)
  or a
  jr z,.no
.yes:
  scf
  ret
.no:
  or a
  ret

; IX = commando -> A = tile flags that stop it (the Marine swims)
cmd_block_flags:
  ld a,(ix+ent.idx)
  cp CMD_MARINE
  ld a,TF_SOLID
  ret z
  ld a,TF_SOLID|TF_WATER
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
  call cmd_can_act
  ret nz
  call cmd_board                ; walked into the truck?
  ret nz
  ld a,(ix+ent.state)
  cp ST_WALK
  jr z,cmd_walk
  cp ST_ATTACK
  jp z,cmd_attack
  ret

cmd_walk:
  ld a,(ix+ent.aux2)
  or a
  jr z,.move
  ; attack order: close in until the target is within reach
  dec a
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  ld a,(iy+ent.type)            ; target gone (exploded, dead...)?
  cp ET_GUARD
  jr z,.alive
  cp ET_BARREL
  jr nz,.lost
.alive:
  bit EF_DEAD,(iy+ent.flags)
  jr nz,.lost
  ld a,(iy+ent.x)
  ld (ix+ent.tx),a
  ld a,(iy+ent.y)
  ld (ix+ent.ty),a
  call cmd_in_reach
  jr nc,.move
  ld (ix+ent.state),ST_ATTACK
  ld (ix+ent.timer),ATTACK_TICKS
  res EF_CRAWL,(ix+ent.flags)
  call face_iy
  jp hud_mark_dirty
.lost:
  ld (ix+ent.aux2),0
  ld (ix+ent.state),ST_IDLE
  ret
.move:
  ; crawling or dragging moves at half speed
  ld a,(ix+ent.flags)
  and 1<<EF_CRAWL
  or (ix+ent.drag)
  jr z,.go
  ld a,(tick)
  and 2
  ret nz
.go:
  call cmd_block_flags
  ld c,a
  call ent_step
  jr z,.stop
  inc (ix+ent.anim)
  call drag_follow
  jp footsteps
.stop:
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.aux2),0
  ret

; IX = commando, IY = target -> carry if close enough to strike
cmd_in_reach:
  ld a,(ix+ent.idx)
  cp CMD_BERET
  jr nz,.ranged
  ld a,(iy+ent.x)
  sub (ix+ent.x)
  add a,KNIFE_RANGE_X
  cp KNIFE_RANGE_X*2+1
  ret nc
  ld a,(iy+ent.y)
  sub (ix+ent.y)
  add a,KNIFE_RANGE_Y
  cp KNIFE_RANGE_Y*2+1
  ret
.ranged:
  ld e,HARPOON_RANGE
  cp CMD_MARINE
  jr z,.r
  ld e,RIFLE_RANGE
.r:
  push de
  call vis_vector
  pop de
  ccf
  ret nc                        ; far beyond any range
  push de
  call vis_distance
  pop de
  cp e
  ret nc
  call los_clear                ; needs a clear shot
  ccf
  ret

; IX faces IY (8-way)
face_iy:
  call vis_vector
  ret c
  call vis_distance
  call vis_angle
  add a,16
  rlca
  rlca
  rlca
  and 7
  ld (ix+ent.dir),a
  ret

cmd_attack:
  dec (ix+ent.timer)
  ld a,(ix+ent.timer)
  cp ATTACK_TICKS/2
  jr nz,.wait
  ; the blow / shot lands halfway through the animation
  ld a,(ix+ent.aux2)
  dec a
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  ld a,(ix+ent.idx)
  cp CMD_SNIPER
  jr z,.rifle
  ld a,SFX_KNIFE                ; knife and harpoon are silent
  call sfx_play
  jr .hit
.rifle:
  ld a,(ammo)
  dec a
  ld (ammo),a
  call hud_mark_dirty
  ld a,SFX_SHOT
  call sfx_play
  push iy
  ld b,(ix+ent.x)               ; the shot is heard far and wide
  ld c,(ix+ent.y)
  ld a,NOISE_SHOT
  ld e,INVESTIGATE_T
  call noise_emit
  pop iy
.hit:
  push ix
  push iy
  pop ix
  ld a,(ix+ent.type)
  cp ET_BARREL
  jr nz,.kill
  call explode
  jr .done
.kill:
  call kill_ent
.done:
  pop ix
.wait:
  ld a,(ix+ent.timer)
  or a
  ret nz
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.aux2),0
  ret

; IX = commando: board the truck when standing in its footprint.
; Returns NZ if boarded.
cmd_board:
  ld a,(ix+ent.x)
  cp M01_TRUCK_X0
  jr c,.no
  cp M01_TRUCK_X1+1
  jr nc,.no
  ld a,(ix+ent.y)
  cp M01_TRUCK_Y0
  jr c,.no
  cp M01_TRUCK_Y1+1
  jr nc,.no
  set EF_BOARDED,(ix+ent.flags)
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.drag),0
  call hud_mark_dirty
  or 1
  ret
.no:
  xor a
  ret

; IX = entity to kill (leaves a corpse)
kill_ent:
  set EF_DEAD,(ix+ent.flags)
  ld (ix+ent.state),ST_DEAD
  ld (ix+ent.drag),0
  ret
