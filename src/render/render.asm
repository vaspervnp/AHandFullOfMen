; ===========================================================================
; Frame renderer (double buffered)
;
; Screens live at &C000 and &8000. Every frame draws into the hidden buffer.
; Each sprite to show (entities in Y order, alert icons, the cursor) becomes
; a draw item: clipped rectangle, source, bank, and its footprint as a mask
; over the dirty-tile map. Each buffer caches the items it last drew, per
; slot, so a frame only touches what changed:
;   1. items that moved / changed frame / vanished mark old + new tiles dirty
;      (to be restored from the map)
;   2. any item over a dirty or touched tile must be redrawn; drawing it over
;      itself is harmless, but it covers what is drawn after it there, so
;      its tiles become touched (one pass in draw order)
;   3. restore dirty tiles, re-plot cone dots on them, redraw marked items
; A freshly cast cone is plotted onto the screen as it is (its tiles only
; become touched), so only erasing an old cone costs tile restores.
; A camera move redraws the whole view and every item, REDRAW_SLICE tile
; rows per tick (the camera stays put meanwhile, see cursor.asm).
REDRAW_SLICE    equ 4
; ===========================================================================

; draw item / cache entry (16 bytes)
IT_SLOT         equ 0           ; item: slot; cache entry: serial last seen
IT_X            equ 1           ; clipped screen x byte
IT_Y            equ 2           ; clipped screen y
IT_W            equ 3           ; clipped width (bytes); 0 = not drawn
IT_H            equ 4
IT_SRC          equ 5           ; first source byte (2)
IT_BANK         equ 7           ; Gate Array RAM config holding the gfx
IT_STRIDE       equ 8           ; source bytes skipped per row
IT_OFFS         equ 9           ; dirty map byte of the top-left tile
IT_MLO          equ 10          ; column mask at IT_OFFS
IT_MHI          equ 11          ;   ... and at IT_OFFS+1
IT_ROWS         equ 12          ; tile rows covered
IT_REDRAW       equ 13          ; item only: draw it this frame
IT_SIZE         equ 16
IT_KEY          equ 7           ; bytes 1..7 identify the picture
SLOT_ICON       equ MAX_ENTS    ; + entity index: '!' / '?' icon
SLOT_CURSOR     equ 2*MAX_ENTS
NSLOTS          equ 2*MAX_ENTS+1

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

; -> carry if the back buffer is complete and should be shown
render_frame:
  call sprites_off
  call back_state
  ld (cur_dirty),hl
  ld hl,cache_c0
  dec b
  jr z,.cache
  ld hl,cache_80
.cache:
  ld (cur_cache),hl
  inc b
  ld a,(view_dirty)
  and b
  ld (full_redraw),a
  jr z,.items
  ; full redraw, REDRAW_SLICE tile rows per call: the old picture stays on
  ; screen (no flip) until the new one is complete
  push bc
  ld a,(redraw_row)
  ld c,a
  ld a,VIEW_TH
  sub c
  cp REDRAW_SLICE+1
  jr c,.last
  ld b,REDRAW_SLICE
  call draw_view_rows
  ld a,c
  ld (redraw_row),a
  pop bc
  call sprites_off
  or a                          ; NC: not finished, don't flip
  ret
.last:
  ld b,a
  call draw_view_rows
  xor a
  ld (redraw_row),a
  pop bc
  ld a,b
  cpl
  ld hl,view_dirty
  and (hl)
  ld (hl),a
  call dirty_all
.items:
  call back_state               ; B = this buffer's bit
  ld a,(cone_fresh)             ; new cone dots to plot in this buffer?
  and b
  ld (cone_plot_all),a
  jr z,.cone_old
  ld a,b
  cpl
  ld hl,cone_fresh
  and (hl)
  ld (hl),a
  ld hl,cone_tiles              ; sprites over them get redrawn
  ld de,touch_map
  ld b,DIRTY_SIZE
.ct:
  ld a,(de)
  or (hl)
  ld (de),a
  inc l
  inc e
  djnz .ct
.cone_old:
  call sort_entities
  call collect_items
  call diff_items
  call expand_dirty
  ld a,(full_redraw)
  or a
  call z,restore_dirty
  call hud_update
  call cone_draw
  call draw_items
  call clear_dirty
  ld hl,touch_map
  xor a
  repeat DIRTY_SIZE
  ld (hl),a
  inc l
  rend
  call sprites_off
  scf                           ; frame complete: flip
  ret

; Render until the back buffer is complete (mission start).
render_full:
  call render_frame
  jr nc,render_full
  ret

; Full redraw: every tile is dirty and nothing is cached as drawn.
dirty_all:
  ld hl,(cur_dirty)
  ld b,DIRTY_SIZE
  ld a,&FF
.d:
  ld (hl),a
  inc hl
  djnz .d
  ld iy,(cur_cache)
  ld de,IT_SIZE
  ld b,NSLOTS
.c:
  ld (iy+IT_W),0
  add iy,de
  djnz .c
  ret

; Build item_buf: sorted entities, alert icons, cursor.
collect_items:
  xor a
  ld (item_count),a
  ld hl,item_buf
  ld (item_wr),hl
  ld hl,draw_list
  ld a,(draw_count)
  or a
  jr z,.icons
  ld b,a
.e:
  push bc
  ld a,(hl)
  inc hl
  push hl
  ld (cur_slot),a
  call ent_ptr
  call ent_item
  pop hl
  pop bc
  djnz .e
.icons:
  call icon_items
  jp cursor_item

; HL = src, B,C = signed position, D,E = size, (cur_slot), (cur_bank)
clip_add:
  call clip_rect
  ; fall through
; HL = src, B,C,D,E = clipped rect, A = stride: append an item (if visible)
add_item:
  inc d
  dec d
  ret z
  ld iy,(item_wr)
  ld (iy+IT_STRIDE),a
  ld (iy+IT_X),b
  ld (iy+IT_Y),c
  ld (iy+IT_W),d
  ld (iy+IT_H),e
  ld (iy+IT_SRC),l
  ld (iy+IT_SRC+1),h
  ld a,(cur_slot)
  ld (iy+IT_SLOT),a
  ld a,(cur_bank)
  ld (iy+IT_BANK),a
  ld (iy+IT_REDRAW),0
  ; tile footprint: columns col0..col1, rows row0..row1
  ld a,b
  rrca
  rrca
  and &3F
  ld l,a                        ; col0
  ld a,b
  add a,d
  dec a
  rrca
  rrca
  and &3F
  sub l
  inc a
  ld h,a                        ; columns covered (1..3)
  ld a,l
  and 7
  add a,a
  add a,a
  add a,h
  add a,a
  add a,mask_tab and &FF        ; table never crosses a page (asserted)
  ld l,a
  ld h,mask_tab>>8
  ld a,(hl)
  ld (iy+IT_MLO),a
  inc l
  ld a,(hl)
  ld (iy+IT_MHI),a
  ld a,b                        ; byte of col0 within the row
  rrca
  rrca
  rrca
  rrca
  rrca
  and 3
  ld l,a
  ld a,c
  rrca
  rrca
  rrca
  and &1F
  ld h,a                        ; row0
  add a,a
  add a,h
  add a,l
  ld (iy+IT_OFFS),a
  ld a,c
  add a,e
  dec a
  rrca
  rrca
  rrca
  and &1F
  sub h
  inc a
  ld (iy+IT_ROWS),a
  ld de,IT_SIZE
  add iy,de
  ld (item_wr),iy
  ld hl,item_count
  inc (hl)
  ret

; IY = item / cache entry: mark its tiles in the back buffer's dirty map.
; Trashes A, B, DE, HL.
mark_rec:
  ld a,(cur_dirty)
  add a,(iy+IT_OFFS)
  ld l,a
  ld a,(cur_dirty+1)
  ld h,a
  ld b,(iy+IT_ROWS)
  ld d,(iy+IT_MLO)
  ld e,(iy+IT_MHI)
.r:
  ld a,(hl)
  or d
  ld (hl),a
  inc l                         ; dirty maps sit in aligned 64-byte blocks
  ld a,(hl)
  or e
  ld (hl),a
  inc l
  inc l
  djnz .r
  ret

; IY = item: NZ if any of its tiles is dirty or touched. Trashes A, B,
; DE, HL.
test_rec:
  ld a,(cur_dirty)
  add a,(iy+IT_OFFS)
  ld l,a
  ld a,(cur_dirty+1)
  ld h,a
  ld a,(iy+IT_OFFS)
  add a,touch_map and &FF
  ld e,a
  ld d,touch_map>>8
  ld b,(iy+IT_ROWS)
.r:
  ld a,(de)
  or (hl)
  and (iy+IT_MLO)
  ret nz
  inc l
  inc e
  ld a,(de)
  or (hl)
  and (iy+IT_MHI)
  ret nz
  inc l
  inc e
  inc l
  inc e
  djnz .r
  xor a                         ; Z: inc l clobbered the flags
  ret

; IY = item: mark its tiles touched (redraw sprites there, keep the tiles).
mark_touch:
  ld a,(iy+IT_OFFS)
  add a,touch_map and &FF
  ld l,a
  ld h,touch_map>>8
  ld b,(iy+IT_ROWS)
  ld d,(iy+IT_MLO)
  ld e,(iy+IT_MHI)
  jr mark_rec.r

; Compare the items with what this buffer shows; dirty the tiles of
; anything that changed or disappeared and update the cache.
diff_items:
  ld hl,render_serial
  inc (hl)
  ld iy,item_buf
  ld a,(item_count)
  or a
  jr z,.gone
  ld b,a
.it:
  push bc
  ld l,(iy+IT_SLOT)
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ld de,(cur_cache)
  add hl,de
  ld (ce_ptr),hl
  ld a,(render_serial)
  ld (hl),a
  push iy
  pop de
  inc hl
  inc de
  ld b,IT_KEY
.cmp:
  ld a,(de)
  cp (hl)
  jr nz,.diff
  inc de
  inc hl
  djnz .cmp
  jr .next
.diff:
  push iy
  ld iy,(ce_ptr)
  ld a,(iy+IT_W)
  or a
  call nz,mark_rec              ; where it was
  pop iy
  call mark_rec                 ; where it is now
  push iy
  pop hl
  inc hl
  ld de,(ce_ptr)
  inc de
  ld bc,IT_REDRAW-1
  ldir
.next:
  ld de,IT_SIZE
  add iy,de
  pop bc
  djnz .it
.gone:
  ld iy,(cur_cache)
  ld b,NSLOTS
.g:
  ld a,(iy+IT_W)
  or a
  jr z,.gn
  ld a,(render_serial)
  cp (iy+IT_SLOT)
  jr z,.gn
  push bc
  call mark_rec
  pop bc
  ld (iy+IT_W),0
.gn:
  ld de,IT_SIZE
  add iy,de
  djnz .g
  ret

; Flag every item over a dirty or touched tile and touch its footprint.
; One pass in draw order is enough: redrawing an item over itself only
; covers the items drawn after it, never those before.
expand_dirty:
  ld iy,item_buf
  ld a,(item_count)
  or a
  ret z
  ld b,a
.it:
  push bc
  call test_rec                 ; changed items hit their own dirty tiles
  jr z,.next
  ld (iy+IT_REDRAW),1
  call mark_touch
.next:
  pop bc
  ld de,IT_SIZE
  add iy,de
  djnz .it
  ret

; Blit the flagged items, back to front.
draw_items:
  ld iy,item_buf
  ld a,(item_count)
  or a
  ret z
  ld b,a
.it:
  push bc
  ld a,(iy+IT_REDRAW)
  or a
  jr z,.next
  ld b,&7F                      ; page in the item's sprite bank
  ld c,(iy+IT_BANK)
  out (c),c
  ld a,(iy+IT_STRIDE)
  ld (blit_core.stride+1),a
  ld l,(iy+IT_Y)                ; DE = back buffer address of (x, y)
  ld h,0
  add hl,hl
  ld de,scr_line
  add hl,de
  ld e,(hl)
  inc hl
  ld a,(hl)
  ld hl,back_hi
  add a,(hl)
  ld d,a
  ld a,e
  add a,(iy+IT_X)
  ld e,a
  jr nc,.nc
  inc d
.nc:
  ld l,(iy+IT_SRC)
  ld h,(iy+IT_SRC+1)
  ld b,(iy+IT_W)
  ld c,(iy+IT_H)
  call blit_core
.next:
  ld de,IT_SIZE
  add iy,de
  pop bc
  djnz .it
  ret

; ((col0 and 7) * 4 + columns) * 2 -> dirty map masks (lo, hi byte)
  align 64
mask_tab:
  repeat 8,sh
  repeat 4,n
  dw ((1<<(n-1))-1)<<(sh-1)
  rend
  rend
  assert (mask_tab and &FF)<=&C0

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

; IX = entity -> draw item (slot in cur_slot)
ent_item:
  ld a,(ix+ent.type)
  cp ET_DECOY
  jr z,.decoy
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
  ld a,(ix+ent.sbank)
  ld (cur_bank),a
  pop bc
  ld d,SPR_W
  ld e,SPR_H
  jp clip_add
; Small 8x8 radio icon standing on its spot
.decoy:
  call ent_screen_pos
  ret c
  inc b                         ; centre the 4-byte icon in the 6-byte box
  ld a,c
  add a,SPR_H-CUR_H
  ld c,a
  ld a,4
  call cursor_gfx
  ld a,RAM_SPRITES
  ld (cur_bank),a
  ld d,CUR_W
  ld e,CUR_H
  jp clip_add

; IX = entity -> A = sprite frame
ent_frame:
  ld a,(ix+ent.type)
  cp ET_BARREL
  jr nz,.not_barrel
  xor a
  ret
.not_barrel:
  cp ET_TRAP                    ; fx sheet: barrel, 3 blasts, trap, bomb
  ld b,FR_TRAP
  jr z,.item
  cp ET_BOMB
  ld b,FR_BOMB
  jr nz,.not_item
.item:
  ld a,b
  ret
.not_item:
  cp ET_FX
  jr nz,.person
  ld a,(ix+ent.anim)            ; 3 ticks per explosion frame: 1..3
  ld b,1
.fx:
  sub 3
  jr c,.fx_done
  inc b
  jr .fx
.fx_done:
  ld a,b
  ret
.person:
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
icon_items:
  ld a,RAM_SPRITES
  ld (cur_bank),a
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
  pop af
  push af
  add a,SLOT_ICON
  ld (cur_slot),a
  inc b
  ld a,c
  sub 9
  ld c,a
  ld a,e
  call cursor_gfx
  ld d,CUR_W
  ld e,CUR_H
  call clip_add
.next:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  ret

cursor_item:
  ld a,SLOT_CURSOR
  ld (cur_slot),a
  ld a,RAM_SPRITES
  ld (cur_bank),a
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
  jp clip_add

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

; Fill draw_list with entity indices sorted by feet Y, visible ones first
; (draw_count of them). draw_list keeps last frame's order, so the
; insertion sort usually just confirms it. Corpses lie flat, so they sort
; 8 lines earlier; hidden slots get key &FF.
  assert MAX_ENTS==16
sort_entities:
  ld ix,ent_table               ; key_by_idx[i] for every slot
  ld hl,key_by_idx
  ld de,ENT_SIZE
  ld b,MAX_ENTS
.scan:
  ld c,&FF
  ld a,(ix+ent.type)
  or a
  jr z,.key
  bit EF_BOARDED,(ix+ent.flags)
  jr nz,.key
  ld a,(ix+ent.y)
  bit EF_DEAD,(ix+ent.flags)
  jr z,.cap
  sub 8
  jr nc,.cap
  xor a
.cap:
  cp &FF
  jr nz,.ok
  dec a
.ok:
  ld c,a
.key:
  ld (hl),c
  inc l
  add ix,de
  djnz .scan
  ; draw_keys[i] = key_by_idx[draw_list[i]]
  ld hl,draw_list
  ld d,key_by_idx>>8
  ld b,MAX_ENTS
.gather:
  ld a,(hl)
  add a,key_by_idx and &FF
  ld e,a
  ld a,(de)
  res 4,l                       ; draw_keys = draw_list - 16
  ld (hl),a
  set 4,l
  inc l
  djnz .gather
  ; insertion sort of (draw_keys[i], draw_list[i])
  ld hl,draw_keys+1
  ld c,MAX_ENTS-1
.i:
  ld a,(hl)
  dec l
  cp (hl)
  inc l
  jr nc,.next                   ; already in order
  ld (sort_key),a
  set 4,l
  ld a,(hl)
  ld (sort_idx),a
  res 4,l
  push hl
.shift:                         ; k[j] = k[j-1], l[j] = l[j-1], j--
  dec l
  ld a,(hl)
  inc l
  ld (hl),a
  set 4,l
  dec l
  ld a,(hl)
  inc l
  ld (hl),a
  res 4,l
  dec l
  ld a,l
  cp draw_keys and &FF
  jr z,.put
  dec l
  ld a,(sort_key)
  cp (hl)
  inc l
  jr c,.shift
.put:
  ld a,(sort_key)
  ld (hl),a
  set 4,l
  ld a,(sort_idx)
  ld (hl),a
  pop hl
.next:
  inc l
  dec c
  jr nz,.i
  ; visible entities: keys before the first &FF
  ld hl,draw_keys
  ld b,0
.count:
  ld a,(hl)
  inc a
  jr z,.done
  inc l
  inc b
  ld a,b
  cp MAX_ENTS
  jr nz,.count
.done:
  ld a,b
  ld (draw_count),a
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
