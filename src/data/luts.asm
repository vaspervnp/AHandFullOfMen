; ===========================================================================
; Lookup tables (assembled, no runtime init)
; ===========================================================================

; Scanline offsets from the start of a screen buffer (add back_hi to the
; high byte): (y % 8) * &800 + (y / 8) * 80
scr_line:
y=0
  repeat 200
  dw ((y mod 8)*&800)+((y>>3)*SCR_W)
y=y+1
  rend

; Character-row offsets (line 0 of each 8-line row)
row_addr:
r=0
  repeat 25
  dw r*SCR_W
r=r+1
  rend

; Map row offsets
map_row_offs:
r=0
  repeat MAP_H
  dw r*MAP_W
r=r+1
  rend

; Mode 0 pen -> bit pattern for the left / right pixel of a byte
pen_left:
p=0
  repeat 16
  db ((p and 1)<<7) or ((p and 2)<<2) or ((p and 4)<<3) or ((p and 8)>>2)
p=p+1
  rend
pen_right:
p=0
  repeat 16
  db (((p and 1)<<7) or ((p and 2)<<2) or ((p and 4)<<3) or ((p and 8)>>2))>>1
p=p+1
  rend

; Direction -> sprite frame, per animation (see tools/gen_art.py layout)
;            N  NE  E  SE  S  SW  W  NW
ftab_stand:  db 0,  1,  2,  3,  4, 27, 26, 25
ftab_walk_a: db 5,  6,  7,  8,  9, 30, 29, 28
ftab_walk_b: db 10, 11, 12, 13, 14, 33, 32, 31
ftab_crawl_a:db 15, 16, 16, 16, 17, 34, 34, 34
ftab_crawl_b:db 18, 19, 19, 19, 20, 35, 35, 35
ftab_attack: db 21, 22, 22, 22, 23, 36, 36, 36

; Direction from movement signs. Index = (sy+1)*3 + (sx+1)
dir_from_sign:
  db DIR_NW, DIR_N, DIR_NE
  db DIR_W,  &FF,   DIR_E
  db DIR_SW, DIR_S, DIR_SE
