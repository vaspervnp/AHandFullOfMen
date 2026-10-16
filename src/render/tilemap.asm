; ===========================================================================
; Tile engine: 8x8 Mode 0 tiles (4 bytes x 8 lines), 20x18 visible
; All drawing goes to the back buffer (back_hi = &80 or &C0).
; ===========================================================================

; A = tile id -> HL = tile graphics
tile_gfx:
  ld l,a
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ld de,tiles
  add hl,de
  ret

; HL = tile graphics, DE = screen address of the tile's first line.
; LDI bumps D when a tile line ends at &xxFF; the borrow from E-4 undoes
; that while adding &800 for the next scanline. Trashes BC.
draw_tile_de:
  repeat 8,line
  ldi
  ldi
  ldi
  ldi
  if line<8
  ld a,e
  sub 4
  ld e,a
  ld a,d
  sbc a,&F8                     ; D + 8 - borrow
  ld d,a
  endif
  rend
  ret

; B = view column (0..19), C = view row (0..24) -> DE = back-buffer address
tile_screen_addr:
  ld l,c
  ld h,0
  add hl,hl
  ld de,row_addr
  add hl,de
  ld e,(hl)
  inc hl
  ld a,(hl)
  ld hl,back_hi
  add a,(hl)
  ld d,a
  ld a,b
  add a,a
  add a,a
  add a,e
  ld e,a
  ret nc
  inc d
  ret

; HL = pointer into map_buf for view origin (camera top-left)
map_cam_ptr:
  ld a,(cam_y)
  ld l,a
  ld h,0
  ld de,map_row_offs
  add hl,hl
  add hl,de
  ld e,(hl)
  inc hl
  ld d,(hl)
  ld hl,map_buf
  add hl,de
  ld a,(cam_x)
  add a,l
  ld l,a
  ret nc
  inc h
  ret

; Redraw the whole 20x18 tactical area into the back buffer.
draw_view:
  ld c,0
  ld b,VIEW_TH
; Draw B view rows starting at row C into the back buffer.
draw_view_rows:
  push bc
  call tile_screen_addr_row     ; DE = screen address of (0, C)
  ld a,(cam_y)                  ; IX = map cell of (0, C)
  add a,c
  ld l,a
  ld h,0
  add hl,hl
  ld bc,map_row_offs
  add hl,bc
  ld c,(hl)
  inc hl
  ld b,(hl)
  ld hl,map_buf
  add hl,bc
  ld a,(cam_x)
  ld c,a
  ld b,0
  add hl,bc
  push hl
  pop ix
  ld a,VIEW_TW
.col:
  push af
  ld a,(ix+0)                   ; HL = tiles + id * 32 (tiles is page aligned)
  inc ix
  rrca
  rrca
  rrca
  ld l,a
  and &1F
  add a,tiles>>8
  ld h,a
  ld a,l
  and &E0
  ld l,a
  push de
  call draw_tile_de
  pop de
  ld a,e                        ; next tile: 4 bytes right
  add a,4
  ld e,a
  jr nc,.nc
  inc d
.nc:
  pop af
  dec a
  jr nz,.col
  pop bc
  inc c
  djnz draw_view_rows
  ret

; C = view row -> DE = back buffer address of its first tile
tile_screen_addr_row:
  ld b,0
  jp tile_screen_addr

; ---------------------------------------------------------------------------
; Dirty tiles. Each screen buffer has a bitmap of the 20x18 view tiles that
; something was drawn over (3 bytes per row, bit n = column 8k+n). Next time
; that buffer is the back buffer, exactly those tiles are redrawn.
; ---------------------------------------------------------------------------
DIRTY_ROW       equ 3
DIRTY_SIZE      equ DIRTY_ROW*VIEW_TH

; B = view column, C = view row. Preserves BC.
mark_tile:
  ld hl,(cur_dirty)
  ld a,c
  add a,a
  add a,c
  ld e,a
  ld a,b
  rrca
  rrca
  rrca
  and &1F
  add a,e
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld a,b
  and 7
  ld e,a
  ld d,0
  push hl
  ld hl,bit_tab
  add hl,de
  ld a,(hl)
  pop hl
  or (hl)
  ld (hl),a
  ret

  align 8                       ; kbd_test / cone indexing never carry
bit_tab:
  db 1,2,4,8,16,32,64,128

; Redraw every marked tile of the back buffer (the map is cleared after
; the frame, since cone_draw still needs it).
restore_dirty:
  ld hl,(cur_dirty)
  ld c,0
.row:
  ld a,(hl)                     ; whole row clean? (the usual case)
  inc l
  or (hl)
  inc l
  or (hl)
  inc hl
  jr nz,.dirty
  inc c
  ld a,c
  cp VIEW_TH
  jr nz,.row
  ret
.dirty:
  dec hl
  dec hl
  dec hl
  ld b,0
  ld e,DIRTY_ROW
.byte:
  ld a,(hl)
  or a
  jr z,.skip8
  push hl
  push de
  ld d,a
.bit:
  srl d
  jr nc,.clean
  push bc
  push de
  call redraw_view_tile
  pop de
  pop bc
.clean:
  inc b
  ld a,d
  or a
  jr nz,.bit
  pop de
  pop hl
  ld a,b                        ; round B up to the next group of 8
  dec a
  or 7
  inc a
  ld b,a
  jr .next
.skip8:
  ld a,b
  add a,8
  ld b,a
.next:
  inc hl
  dec e
  jr nz,.byte
  inc c
  ld a,c
  cp VIEW_TH
  jr nz,.row
  ret

; Clear the back buffer's dirty map (after a full redraw).
clear_dirty:
  ld hl,(cur_dirty)
  xor a
  repeat DIRTY_SIZE
  ld (hl),a
  inc l                         ; maps sit in aligned 64-byte blocks
  rend
  ret

; Redraw view tile (B, C) from the map into the back buffer.
redraw_view_tile:
  ld a,(cam_y)
  add a,c
  ld l,a
  ld h,0
  add hl,hl
  ld de,map_row_offs
  add hl,de
  ld e,(hl)
  inc hl
  ld d,(hl)
  ld hl,map_buf
  add hl,de
  ld a,(cam_x)
  add a,b
  ld e,a
  ld d,0
  add hl,de
  ld a,(hl)
  push af
  call tile_screen_addr
  pop af
  push de
  call tile_gfx
  pop de
  jp draw_tile_de

; ---------------------------------------------------------------------------
; Map queries (world coordinates)
; ---------------------------------------------------------------------------

; B = world x, C = world y -> HL = map_buf cell, A = tile id
map_cell:
  ld a,c
  rrca
  rrca
  rrca
  and &1F
  ld l,a
  ld h,0
  add hl,hl
  ld de,map_row_offs
  add hl,de
  ld e,(hl)
  inc hl
  ld d,(hl)
  ld a,b
  rrca
  rrca
  and &3F
  ld hl,map_buf
  add hl,de
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld a,(hl)
  ret

; B = world x, C = world y -> A = tile attribute flags
map_flags:
  call map_cell
  ld l,a
  ld h,tile_attrs>>8            ; page aligned
  ld a,(hl)
  ret

; ---------------------------------------------------------------------------
; Map tiles (B, C) .. (B+D-1, C+E-1) were replaced in map_buf: redraw them
; in both buffers and recast the vision cone (it may see further now).
; (Path searches read map_buf directly.)
; ---------------------------------------------------------------------------
map_rect_changed:
  ld a,&FF
  ld (cone_key),a
.row:
  push bc
  push de
.col:
  push bc
  push de
  call map_tile_changed
  pop de
  pop bc
  inc b
  dec d
  jr nz,.col
  pop de
  pop bc
  inc c
  dec e
  jr nz,.row
  ret

; B = map column, C = map row: if visible, mark it in both dirty maps
map_tile_changed:
  ld a,b
  ld hl,cam_x
  sub (hl)
  cp VIEW_TW
  ret nc
  ld b,a
  ld a,c
  ld hl,cam_y
  sub (hl)
  cp VIEW_TH
  ret nc
  ld c,a
  ld hl,(cur_dirty)
  push hl
  ld hl,dirty_c0
  ld (cur_dirty),hl
  call mark_tile
  ld hl,dirty_80
  ld (cur_dirty),hl
  call mark_tile
  pop hl
  ld (cur_dirty),hl
  ret
