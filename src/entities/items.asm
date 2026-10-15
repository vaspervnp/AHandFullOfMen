; ===========================================================================
; Explosive barrels, explosions, the radio tower
; ===========================================================================

BLAST_R         equ 32          ; visual units: 2 tiles across, 4 up/down
FX_TICKS        equ 9           ; explosion animation length
CHAIN_FUSE      equ 4           ; ticks before a nearby barrel goes up

; Per tick: barrel fuses and explosion animations.
items_update:
  ld a,CMD_COUNT
.lp:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_BARREL
  jr z,.barrel
  cp ET_FX
  jr nz,.next
  inc (ix+ent.anim)
  ld a,(ix+ent.anim)
  cp FX_TICKS
  jr c,.next
  ld (ix+ent.type),ET_NONE      ; animation over
  jr .next
.barrel:
  ld a,(ix+ent.fuse)
  or a
  jr z,.next
  dec (ix+ent.fuse)
  call z,explode
.next:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  ret

; IX = barrel. It becomes the explosion; everything within BLAST_R dies,
; nearby barrels catch, the tower falls if it is close enough.
explode:
  ld (ix+ent.type),ET_FX
  ld (ix+ent.anim),0
  ld (ix+ent.fuse),0
  ld a,SFX_EXPLOSION
  call sfx_play
  call drop_dragged_ent         ; whoever was dragging it lets go
  ; blast
  xor a
.lp:
  push af
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  ld a,(iy+ent.type)
  cp ET_COMMANDO
  jr z,.living
  cp ET_GUARD
  jr z,.living
  cp ET_BARREL
  jr nz,.next
  ld a,(iy+ent.fuse)            ; another barrel: light its fuse
  or a
  jr nz,.next
  call in_blast
  jr nc,.next
  ld (iy+ent.fuse),CHAIN_FUSE
  jr .next
.living:
  ld a,(iy+ent.flags)
  and (1<<EF_DEAD)|(1<<EF_BOARDED)
  jr nz,.next
  call in_blast
  jr nc,.next
  ld (iy+ent.hp),0
  push ix
  push iy
  pop ix
  call kill_ent
  pop ix
.next:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  ; the tower
  ld a,(tower_down)
  or a
  jr nz,.alarm
  ld b,M01_TOWER_X
  ld c,M01_TOWER_Y
  call vis_vector_pt
  jr c,.alarm
  call vis_distance
  cp BLAST_R+8
  call c,destroy_tower
.alarm:
  call hud_mark_dirty
  jp alarm_all

; IX = blast centre, IY = entity -> carry if within BLAST_R
in_blast:
  call vis_vector
  ccf
  ret nc                        ; out of range entirely
  call vis_distance
  cp BLAST_R+1
  ret

; Knock the radio tower down: the top half becomes snow, the base rubble.
destroy_tower:
  ld a,1
  ld (tower_down),a
  ld hl,map_buf+M01_TOWER_ROW*MAP_W+M01_TOWER_COL
  ld b,4
  ld c,TILE_SNOW
.row:
  ld a,b
  cp 2
  jr nz,.fill
  ld c,TILE_RUBBLE
.fill:
  ld (hl),c
  inc hl
  ld a,c
  cp TILE_RUBBLE
  jr nz,.same
  ld a,TILE_SCORCH
.same:
  ld (hl),a
  ld de,MAP_W-1
  add hl,de
  djnz .row
  ld a,3
  ld (view_dirty),a
  ret

; Every guard drops what it is doing and joins the fight.
alarm_all:
  ld a,(alarm)
  or a
  ret nz
  ld a,1
  ld (alarm),a
  ld a,ALARM_SECONDS
  ld (alarm_secs),a
  ld a,SFX_ALARM
  call sfx_play
  push ix
  ld a,GUARD_FIRST
.all:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_GUARD
  jr nz,.skip
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.skip
  ld a,(ix+ent.ai)
  cp AI_ALARM
  jr z,.skip
  ld (ix+ent.ai),AI_ALARM
  ld (ix+ent.ai_seen),&FF
  ld (ix+ent.state),ST_IDLE
.skip:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.all
  pop ix
  jp hud_mark_dirty

; ---------------------------------------------------------------------------
; Dragging (Green Beret): G picks up the nearest barrel or body within
; reach, G again drops it. The load trails behind him; he moves at half
; speed and can't crawl.
; ---------------------------------------------------------------------------
DRAG_REACH_X    equ 4
DRAG_REACH_Y    equ 8

drag_key:
  ld a,(sel_cmd)
  cp CMD_BERET
  ret nz
  call sel_ent
  ld a,(ix+ent.flags)
  and (1<<EF_DEAD)|(1<<EF_BOARDED)
  ret nz
  ld a,(ix+ent.drag)
  or a
  jr z,.grab
  ld (ix+ent.drag),0
  jp hud_mark_dirty
.grab:
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  push ix
  ld a,CMD_COUNT
.lp:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_BARREL
  jr z,.cand
  cp ET_GUARD
  jr nz,.next
  bit EF_DEAD,(ix+ent.flags)    ; only bodies
  jr z,.next
.cand:
  ld a,(ix+ent.x)
  sub b
  add a,DRAG_REACH_X
  cp DRAG_REACH_X*2+1
  jr nc,.next
  ld a,(ix+ent.y)
  sub c
  add a,DRAG_REACH_Y
  cp DRAG_REACH_Y*2+1
  jr nc,.next
  pop af                        ; found: A = index
  pop ix
  inc a
  ld (ix+ent.drag),a
  res EF_CRAWL,(ix+ent.flags)
  jp hud_mark_dirty
.next:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  pop ix
  ret

; IX = dragging commando: put the load just behind him.
drag_follow:
  ld a,(ix+ent.drag)
  or a
  ret z
  dec a
  ld e,(ix+ent.dir)
  ld d,0
  ld hl,dir_dx
  add hl,de
  ld b,(hl)
  ld hl,dir_dy
  add hl,de
  ld c,(hl)
  ld a,(ix+ent.x)
  sub b
  sub b
  sub b
  ld b,a
  ld a,(ix+ent.y)
  sub c
  sub c
  sub c
  ld c,a
  ld a,(ix+ent.drag)
  dec a
  push ix
  call ent_ptr
  ld (ix+ent.x),b
  ld (ix+ent.y),c
  pop ix
  ret

; IX = entity that stops existing as a load: anyone dragging it lets go.
drop_dragged_ent:
  ld a,(ix+ent.idx)
  inc a
  ld b,a
  push ix
  xor a
.lp:
  push af
  call ent_ptr
  ld a,(ix+ent.drag)
  cp b
  jr nz,.next
  ld (ix+ent.drag),0
.next:
  pop af
  inc a
  cp CMD_COUNT
  jr nz,.lp
  pop ix
  ret

; Unit direction vectors (x in X units, y in lines/2 so that *3 trails)
;          N   NE  E  SE  S  SW  W   NW
dir_dx: db 0,  1,  1, 1,  0, -1, -1, -1
dir_dy: db -2, -2, 0, 2,  2,  2,  0, -2
