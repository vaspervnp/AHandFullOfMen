; ===========================================================================
; Mission setup and end-of-mission checks
; ===========================================================================

; HL = spawn records, DE = map tiles, B = cam x, C = cam y
mission_load:
  push hl
  ld a,b
  ld (cam_x),a
  ld a,c
  ld (cam_y),a
  ex de,hl
  ld de,map_buf
  ld bc,MAP_W*MAP_H
  ldir
  ; clear entity table
  ld hl,ent_table
  ld de,ent_table+1
  ld bc,MAX_ENTS*ENT_SIZE-1
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
  ld a,SCR_W/2
  ld (cursor_x),a
  ld a,PLAY_H/2
  ld (cursor_y),a
  xor a
  ld (tick),a
  ld (cone_count),a
  dec a                         ; &FF: no cone shown or pinned
  ld (cone_pinned),a
  ld (cone_guard),a
  ld (cone_key),a
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

; Decide which cursor to show for what is under it.
update_cursor_frame:
  call cursor_world
  call ent_at
  ld a,0
  jr nc,.set
  ld a,(ix+ent.type)
  cp ET_GUARD
  ld a,0
  jr nz,.set
  ld a,(sel_cmd)
  cp CMD_BERET
  ld a,0
  jr nz,.set
  inc a                         ; knife target
.set:
  ld (cursor_frame),a
  ret

; All commandos dead -> mission failed.
check_end:
  ld a,(game_over)
  or a
  ret nz
  xor a
.lp:
  push af
  call ent_ptr
  pop af
  bit EF_DEAD,(ix+ent.flags)
  ret z                         ; someone is still alive
  inc a
  cp CMD_COUNT
  jr nz,.lp
  ld a,1
  ld (game_over),a
  jp hud_mark_dirty
