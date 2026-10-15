; ===========================================================================
; Frame renderer (double buffered)
;
; Screens live at &C000 and &8000. Every frame draws into the hidden buffer:
;   1. full tactical redraw if the camera moved, otherwise restore the tiles
;      under every sprite drawn into this buffer two frames ago
;   2. HUD if it changed
;   3. entities in Y order, alert icons, then the cursor
; then flips the CRTC to show it.
; ===========================================================================

; -> B = dirty bit of the back buffer (1 = &C000, 2 = &8000), HL = its
;    dirty-tile map
back_state:
  ld a,(back_hi)
  cp &C0
  ld b,1
  ld hl,dirty_c0
  ret z
  ld b,2
  ld hl,dirty_80
  ret

render_frame:
  call sprites_off
  call back_state
  ld (cur_dirty),hl
  ld a,(view_dirty)
  and b
  jr z,.restore
  ld a,b
  cpl
  ld hl,view_dirty
  and (hl)
  ld (hl),a
  call draw_view
  call clear_dirty
  jr .hud
.restore:
  call restore_dirty
.hud:
  call hud_update
  call cone_draw
  call sort_entities
  call sprites_on
  ; entities, back to front
  ld hl,draw_list
  ld a,(draw_count)
  or a
  jr z,.icons
.e:
  push af
  ld a,(hl)
  inc hl
  push hl
  call ent_ptr
  call draw_entity
  pop hl
  pop af
  dec a
  jr nz,.e
.icons:
  call draw_alert_icons
  call draw_cursor
  jp sprites_off

; Mark the rectangle returned by blit_clipped (B,C,D,E) dirty if visible.
record_rect:
  ld a,d
  or a
  ret z
  jp mark_rect

; IX = entity -> B,C = signed screen position of its sprite's top-left,
; carry set if entirely off screen.
ent_screen_pos:
  ld a,(cam_x)
  add a,a
  add a,a
  add a,SPR_W/2
  ld c,a
  ld a,(ix+ent.x)
  sub c
  jr c,.xneg
  cp SCR_W
  ccf
  ret c
  jr .xok
.xneg:
  cp 256-SPR_W+1
  ret c
.xok:
  ld b,a
  ld a,(cam_y)
  add a,a
  add a,a
  add a,a
  add a,SPR_H-1
  ld c,a
  ld a,(ix+ent.y)
  sub c
  jr c,.yneg
  cp PLAY_H
  ccf
  ret c
  jr .yok
.yneg:
  cp 256-SPR_H+1
  ret c
.yok:
  ld c,a
  or a
  ret

; IX = entity
draw_entity:
  ld a,(ix+ent.type)
  cp ET_DECOY
  jr z,draw_decoy
  call ent_screen_pos
  ret c
  push bc
  call ent_frame                ; A = frame number
  ld l,a                        ; HL = gfx + frame * 192
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ld d,h
  ld e,l
  add hl,hl
  add hl,de
  ld e,(ix+ent.gfx)
  ld d,(ix+ent.gfx+1)
  add hl,de
  pop bc
  ld d,SPR_W
  ld e,SPR_H
  call blit_clipped
  jp record_rect

; Small 8x8 radio icon standing on its spot
draw_decoy:
  call ent_screen_pos
  ret c
  inc b                         ; centre the 4-byte icon in the 6-byte box
  ld a,c
  add a,SPR_H-CUR_H
  ld c,a
  ld a,4
  call cursor_gfx
  ld d,CUR_W
  ld e,CUR_H
  call blit_clipped
  jp record_rect

; IX = entity -> A = sprite frame
ent_frame:
  bit EF_DEAD,(ix+ent.flags)
  ld a,FR_CORPSE
  ret nz
  ld hl,ftab_attack
  ld a,(ix+ent.state)
  cp ST_ATTACK
  jr z,.dir
  cp ST_WALK
  jr nz,.still
  ld a,(ix+ent.timer)           ; guards pausing at a waypoint stand still
  or a
  jr nz,.still
  bit 2,(ix+ent.anim)
  bit EF_CRAWL,(ix+ent.flags)
  jr nz,.crawl
  ld hl,ftab_walk_a
  bit 2,(ix+ent.anim)
  jr z,.dir
  ld hl,ftab_walk_b
  jr .dir
.crawl:
  ld hl,ftab_crawl_a
  bit 2,(ix+ent.anim)
  jr z,.dir
  ld hl,ftab_crawl_b
  jr .dir
.still:
  ld hl,ftab_stand
  bit EF_CRAWL,(ix+ent.flags)
  jr z,.dir
  ld hl,ftab_crawl_a
.dir:
  ld a,(ix+ent.dir)
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld a,(hl)
  ret

; '!' over suspicious / alarmed guards, '?' over investigating ones
draw_alert_icons:
  ld a,GUARD_FIRST
.lp:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_GUARD
  jr nz,.next
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.next
  ld a,(ix+ent.ai)
  ld e,2                        ; '!'
  cp AI_SUSPICIOUS
  jr z,.draw
  cp AI_ALARM
  jr z,.draw
  ld e,3                        ; '?'
  cp AI_INVESTIGATE
  jr nz,.next
.draw:
  push de
  call ent_screen_pos
  pop de
  jr c,.next
  inc b
  ld a,c
  sub 9
  ld c,a
  ld a,e
  call cursor_gfx
  ld d,CUR_W
  ld e,CUR_H
  call blit_clipped
  call record_rect
.next:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  ret

draw_cursor:
  ld a,(cursor_x)
  dec a
  ld b,a
  ld a,(cursor_y)
  sub 3
  ld c,a
  ld a,(cursor_frame)
  call cursor_gfx
  ld d,CUR_W
  ld e,CUR_H
  call blit_clipped
  jp record_rect

; A = cursor sheet frame -> HL
cursor_gfx:
  ld l,a
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl                     ; * 64
  push de
  ld de,spr_cursor
  add hl,de
  pop de
  ret

; Fill draw_list with live entity indices sorted by feet Y (insertion sort).
sort_entities:
  xor a
  ld (draw_count),a
  ld ix,ent_table
  ld c,0                        ; entity index
.scan:
  ld a,(ix+ent.type)
  or a
  jr z,.skip
  ; insert index C keyed by Y
  ld hl,draw_count
  ld b,(hl)
  inc (hl)
  ld a,b
  ld hl,draw_list
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ; HL -> slot b (end); shift larger keys right
.ins:
  ld a,b
  or a
  jr z,.put
  dec hl
  push hl
  ld a,(hl)                     ; previous entity index
  push bc
  call ent_ptr_y                ; A = its Y
  pop bc
  pop hl
  cp (ix+ent.y)
  jr c,.put_after
  jr z,.put_after
  ld a,(hl)
  inc hl
  ld (hl),a
  dec hl
  dec b
  jr .ins
.put_after:
  inc hl
.put:
  ld (hl),c
.skip:
  ld de,ENT_SIZE
  add ix,de
  inc c
  ld a,c
  cp MAX_ENTS
  jr nz,.scan
  ret

; A = entity index -> A = its Y (corpses sort first: they lie flat)
ent_ptr_y:
  push ix
  call ent_ptr
  ld a,(ix+ent.y)
  bit EF_DEAD,(ix+ent.flags)
  jr z,.alive
  sub 8
  jr nc,.alive
  xor a
.alive:
  pop ix
  ret

; Show the back buffer and make the old front buffer the new back buffer.
flip:
  ld a,(back_hi)
  cp &C0
  ld a,&30
  jr z,.r12
  ld a,&20
.r12:
  ld bc,&BC0C
  out (c),c
  ld b,CRTC_DATA
  out (c),a
  ld a,(back_hi)
  xor &40
  ld (back_hi),a
  jp wait_vsync                 ; the CRTC latches R12 at the next frame
