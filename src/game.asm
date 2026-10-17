; ===========================================================================
; Mission setup and end-of-mission checks
; ===========================================================================

; Start mission (cur_mission): descriptor -> mis_*, then mission_load.
mission_begin:
  call mission_select
  ld hl,(mis+MIS_SPAWNS)
  ld de,(mis+MIS_MAP)
  ld a,(mis+MIS_CAM_X)
  ld b,a
  ld a,(mis+MIS_CAM_Y)
  ld c,a
  jp mission_load

; Copy the block of (cur_mission) out of bank 7 into mis_buf, and its
; descriptor into mis (menu texts need it too).
mission_select:
  ld a,(cur_mission)
  add a,a
  ld l,a
  ld h,0
  ld de,mission_table
  add hl,de
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ld de,mis_buf                 ; bank 7 -> mis_buf, through bounce
  ld a,MIS_BUF_SIZE/MAP_W
.chunk:
  push af
  ld bc,&7F00+RAM_BANK7
  out (c),c
  push de
  ld de,bounce
  ld bc,MAP_W
  ldir
  pop de
  ld bc,&7F00+RAM_BASE64
  out (c),c
  push hl
  ld hl,bounce
  ld bc,MAP_W
  ldir
  pop hl
  pop af
  dec a
  jr nz,.chunk
  ld hl,mis_buf                 ; the descriptor heads the block
  ld de,mis
  ld bc,MIS_SIZE
  ldir
  ret

; HL = spawn records, DE = map tiles, B = cam x, C = cam y
mission_load:
  push hl
  ld a,b
  ld (cam_x),a
  ld a,c
  ld (cam_y),a
  ex de,hl                      ; packed map -> map_buf
  ld a,(mis+MIS_MAP_BANK)
  call map_unpack
  ; clear entity table
  ld hl,ent_table
  ld de,ent_table+1
  ld bc,MAX_ENTS*ENT_SIZE-1
  ld (hl),0
  ldir
  ld hl,path_table              ; and every unit's route
  ld de,path_table+1
  ld bc,PATH_SLOTS*PATH_SLOT_SIZE-1
  ld (hl),0
  ldir
  pop hl
  xor a
.spawn:
  push af
  ld a,(hl)
  cp &FF
  jr z,.done
  pop af
  push af
  push hl
  call ent_ptr
  pop hl
  pop af
  ld (ix+ent.idx),a
  push af
  ld a,(hl)
  ld (ix+ent.type),a
  inc hl
  ld a,(hl)
  ld (ix+ent.x),a
  ld (ix+ent.tx),a
  inc hl
  ld a,(hl)
  ld (ix+ent.y),a
  ld (ix+ent.ty),a
  inc hl
  ld a,(hl)
  ld (ix+ent.dir),a
  inc hl
  ld a,(hl)
  ld (ix+ent.gfx),a
  inc hl
  ld a,(hl)
  ld (ix+ent.gfx+1),a
  inc hl
  ld a,(hl)
  ld (ix+ent.sbank),a
  inc hl
  ld a,(hl)
  ld (ix+ent.hp),a
  inc hl
  ld e,(hl)
  inc hl
  ld d,(hl)
  inc hl
  ; route table entry
  ld a,(ix+ent.idx)
  push hl
  add a,a
  ld l,a
  ld h,0
  ld bc,ent_route
  add hl,bc
  ld (hl),e
  inc hl
  ld (hl),d
  pop hl
  ld a,(ix+ent.type)
  cp ET_COMMANDO
  jr nz,.not_cmd
  ld (ix+ent.role),e            ; commandos: the route word is the role
.not_cmd:
  cp ET_GUARD
  jr nz,.next
  ld (ix+ent.ai_seen),&FF
  ld (ix+ent.state),ST_WALK
  push hl
  call guard_load_waypoint
  pop hl
.next:
  pop af
  inc a
  jr .spawn
.done:
  pop af
  xor a
  ld (sel_cmd),a
  ld (alarm),a
  ld (game_over),a
  ld (target_down),a
  ld (sec_ticks),a
  ld (mission_secs),a
  ld (mission_secs+1),a
  ld a,RIFLE_AMMO
  ld (ammo),a
  ld a,TRAP_COUNT
  ld (traps),a
  ld a,BOMB_COUNT
  ld (bombs),a
  ld a,SCR_W/2
  ld (cursor_x),a
  ld a,PLAY_H/2
  ld (cursor_y),a
  xor a
  ld (tick),a
  ld (cone_count),a
  ld (cone_fresh),a
  ld (cone_pending),a
  dec a                         ; &FF: no cone shown or pinned
  ld (cone_pinned),a
  ld (cone_guard),a
  ld (cone_key),a
  ld (pf_job),a                 ; no search running
  ld hl,cone_tiles              ; full redraw follows: forget old cone tiles
  ld b,DIRTY_SIZE
  xor a
.ct:
  ld (hl),a
  inc hl
  djnz .ct
  ld a,3
  ld (view_dirty),a
  ld (hud_dirty),a
  ld (hud_bg),a
  ret

; Cursor shows the attack marker when the selected commando can attack
; what is under it.
update_cursor_frame:
  call cursor_world
  call ent_at
  jr c,.found
  ld a,&FF
.found:
  ld (cursor_ent),a             ; reused by the cone this tick
  cp CMD_COUNT
  ld a,0
  jr c,.set                     ; a commando
  ld a,(cursor_ent)
  inc a
  ld a,0
  jr z,.set                     ; nothing there
  ld a,(ix+ent.type)
  ld (click_type),a
  call sel_ent
  call cmd_can_attack
  ld a,0
  jr nc,.set
  inc a
.set:
  ld (cursor_frame),a
  ret

; Win: tower down and every surviving commando aboard the truck.
; Lose: the whole squad is dead (reinforcements are handled by clock_update).
END_LOST        equ 0           ; end_reason values
END_REINFORCED  equ 1
END_ESCAPED     equ 2
END_DELAY       equ 50          ; ticks before the debrief screen
ALARM_SECONDS   equ 60

check_end:
  ld a,(game_over)
  or a
  ret nz
  ld bc,0                       ; B = alive, C = alive and on foot
  xor a
.lp:
  push af
  call ent_ptr
  pop af
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.next
  inc b
  bit EF_BOARDED,(ix+ent.flags)
  jr nz,.next
  inc c
.next:
  inc a
  cp CMD_COUNT
  jr nz,.lp
  ld a,b
  or a
  ld a,END_LOST
  jr z,end_fail
  ld a,(target_down)
  or a
  ret z
  ld a,c
  or a
  ret nz
  ld a,END_ESCAPED
  ld (end_reason),a
  ld a,2
  jr end_set

; A = end_reason
end_fail:
  ld (end_reason),a
  ld a,1
end_set:
  ld (game_over),a
  ld a,END_DELAY
  ld (end_timer),a
  call psg_init                 ; siren off
  jp hud_mark_dirty

; Mission clock (seconds) and the alarm countdown.
clock_update:
  ld hl,sec_ticks
  inc (hl)
  ld a,(hl)
  cp 25
  ret c
  ld (hl),0
  ld hl,(mission_secs)
  inc hl
  ld (mission_secs),hl
  ld a,(alarm)
  or a
  ret z
  call hud_mark_dirty
  ld hl,alarm_secs
  dec (hl)
  ret nz
  ld a,END_REINFORCED
  jr end_fail

; ---------------------------------------------------------------------------
; HL = packed map (format: tools/map2asm.py) in RAM config A -> map_buf.
; The source bank is paged in for each byte read; matches copy within
; map_buf. Then snow specks and shading are scattered over the plain snow.
; ---------------------------------------------------------------------------
MAP_MIN_MATCH   equ 4

map_unpack:
  ld (mu_port),a
  ld a,&7F
  ld (mu_port+1),a
  ld de,map_buf
.token:
  call mu_byte
  bit 7,a
  jr nz,.match
  inc a                         ; &00-&7F: A+1 literal tiles
  ld b,a
.lit:
  call mu_byte
  ld (de),a
  inc de
  djnz .lit
  jr .more
.match:
  and &7F                       ; &80-&FF: copy from earlier output
  add a,MAP_MIN_MATCH
  ld (mu_len),a
  call mu_byte
  ld c,a
  call mu_byte
  ld b,a                        ; BC = distance back
  push hl
  ld h,d
  ld l,e
  or a
  sbc hl,bc
  ld a,(mu_len)
  ld c,a
  ld b,0
  ldir                          ; overlapping copies repeat, as intended
  pop hl
.more:
  ld a,e
  cp (map_buf+MAP_W*MAP_H) and &FF
  jr nz,.token
  ld a,d
  cp (map_buf+MAP_W*MAP_H)>>8
  jr nz,.token
  ; specks and shading: about 1 snow tile in 10, the same every load
  ld hl,&ACE1
  ld (mu_seed),hl
  ld hl,map_buf
  ld bc,MAP_W*MAP_H
.snow:
  ld a,(hl)
  or a                          ; TILE_SNOW
  jr nz,.next
  push hl
  call mu_rand
  pop hl
  cp 13
  jr c,.speck
  cp 26
  jr nc,.next
  ld (hl),2                     ; snow_shade
  jr .next
.speck:
  ld (hl),1                     ; snow_speck
.next:
  inc hl
  dec bc
  ld a,b
  or c
  jr nz,.snow
  ret

; -> A = (HL), HL+1, read from the map's RAM bank (base RAM paged back)
mu_byte:
  push bc
  ld bc,(mu_port)
  out (c),c
  ld a,(hl)
  inc hl
  ld c,RAM_BASE64
  out (c),c
  pop bc
  ret

; -> A = next byte of the speck generator (xorshift 7/9/8)
mu_rand:
  ld hl,(mu_seed)
  ld a,h
  rra
  ld a,l
  rra
  xor h
  ld h,a
  ld a,l
  rra
  ld a,h
  rra
  xor l
  ld l,a
  xor h
  ld h,a
  ld (mu_seed),hl
  ret

; ---------------------------------------------------------------------------
; Training tips: the first zone of (mis+MIS_TIPS) holding the selected
; commando puts its text on the HUD objective line. Zone: x0, x1, y0, y1
; (world, inclusive), text (dw, 21 chars: "> " and the tip).
; ---------------------------------------------------------------------------
tips_update:
  ld hl,(mis+MIS_TIPS)
  ld a,h
  or l
  ret z
  push hl
  ld a,(sel_cmd)
  call ent_ptr
  pop hl
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
.zone:
  ld a,(hl)
  cp &FF
  ret z
  ld a,b
  cp (hl)                       ; x < x0?
  jr c,.skip0
  inc hl
  ld a,(hl)
  cp b                          ; x1 < x?
  jr c,.skip1
  inc hl
  ld a,c
  cp (hl)                       ; y < y0?
  jr c,.skip2
  inc hl
  ld a,(hl)
  cp c                          ; y1 < y?
  jr c,.skip3
  inc hl
  ld e,(hl)
  inc hl
  ld d,(hl)
  ld hl,(mis+MIS_TXT_HUD1)
  or a
  sbc hl,de
  ret z                         ; already showing
  ld (mis+MIS_TXT_HUD1),de
  jp hud_mark_dirty
.skip0:
  inc hl
.skip1:
  inc hl
.skip2:
  inc hl
.skip3:
  inc hl
  inc hl
  inc hl
  jr .zone
