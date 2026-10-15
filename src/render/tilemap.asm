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
  call map_cam_ptr
  ld c,0
.row:
  ld b,0
.col:
  push bc
  push hl
  ld a,(hl)
  push af
  call tile_screen_addr
  pop af
  push de
  call tile_gfx
  pop de
  call draw_tile_de
  pop hl
  inc hl
  pop bc
  inc b
  ld a,b
  cp VIEW_TW
  jr nz,.col
  ld de,MAP_W-VIEW_TW
  add hl,de
  inc c
  ld a,c
  cp VIEW_TH
  jr nz,.row
  ret

; ---------------------------------------------------------------------------
; Dirty tiles. Each screen buffer has a bitmap of the 20x18 view tiles that
; something was drawn over (3 bytes per row, bit n = column 8k+n). Next time
; that buffer is the back buffer, exactly those tiles are redrawn.
; ---------------------------------------------------------------------------
DIRTY_ROW       equ 3
DIRTY_SIZE      equ DIRTY_ROW*VIEW_TH

; Mark the tiles under a screen rectangle (clipped to the view).
; B = x byte, C = y line, D = width bytes, E = height lines
mark_rect:
  ld a,b
  add a,d
  dec a
  rrca
  rrca
  and &3F
  ld d,a                        ; last column
  ld a,c
  add a,e
  dec a
  rrca
  rrca
  rrca
  and &1F
  ld e,a                        ; last row
  ld a,b
  rrca
  rrca
  and &3F
  ld b,a                        ; first column
  ld (.col0+1),a
  ld a,c
  rrca
  rrca
  rrca
  and &1F
  ld c,a                        ; first row
.row:
.col0:
  ld b,0
.col:
  push de
  call mark_tile
  pop de
  ld a,b
  inc b
  cp d
  jr nz,.col
  ld a,c
  inc c
  cp e
  jr nz,.row
  ret

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

bit_tab:
  db 1,2,4,8,16,32,64,128

; Redraw and clear every marked tile of the back buffer.
restore_dirty:
  ld hl,(cur_dirty)
  ld c,0
.row:
  ld b,0
  ld e,DIRTY_ROW
.byte:
  ld a,(hl)
  or a
  jr z,.skip8
  ld (hl),0
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
  ld b,DIRTY_SIZE
  xor a
.lp:
  ld (hl),a
  inc hl
  djnz .lp
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
  ld h,0
  ld de,tile_attrs
  add hl,de
  ld a,(hl)
  ret
