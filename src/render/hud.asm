; ===========================================================================
; Tactical status bar (lines 144..199): commando portraits, health, mode,
; objective and alarm state. Redrawn into the back buffer when hud_dirty
; has that buffer's bit set.
; ===========================================================================

HUD_ROW         equ 18          ; first character row of the HUD
PORTRAIT_Y      equ 152
PORTRAIT_W      equ 8
PORTRAIT_H      equ 24
TEXT_X          equ 34
HUD_CACHE_ROW   equ 32          ; ink + up to 30 chars + 0
HUD_CACHE_SIZE  equ HUD_CACHE_ROW*5+3   ; 5 text rows, 3 portrait keys

hud_mark_dirty:
  ld a,3
  ld (hud_dirty),a
  ret

; Draw the HUD if this back buffer needs it.
hud_update:
  ld a,(back_hi)
  cp &C0
  ld b,1
  jr z,.buf
  ld b,2
.buf:
  ld a,(hud_dirty)
  and b
  ret z
  ld a,b
  cpl
  ld hl,hud_dirty
  and (hl)
  ld (hl),a
  ; panel background only once per mission and buffer: everything drawn
  ; on top of it overwrites itself in place
  ld hl,hud_bg
  ld a,(hl)
  and b
  jr z,hud_contents
  ld a,b
  cpl
  and (hl)
  ld (hl),a
  call hud_background
  call hud_cache_clear
  jr hud_contents

hud_background:
  ld c,HUD_ROW
.row:
  ld b,0
.col:
  push bc
  call tile_screen_addr
  ld a,c
  cp HUD_ROW
  ld a,35                       ; hud_edge
  jr z,.edge
  ld a,34                       ; hud_bg
.edge:
  push de
  call tile_gfx
  pop de
  call draw_tile_de
  pop bc
  inc b
  ld a,b
  cp VIEW_TW
  jr nz,.col
  inc c
  ld a,c
  cp 25
  jr nz,.row
  ret

hud_contents:
  ; portraits, frames and health bars for the three commandos
  xor a
.cmd:
  push af
  call hud_portrait
  pop af
  inc a
  cp 3
  jr nz,.cmd

  ; selected commando's details
  ld a,PEN_HUD
  ld (text_paper),a
  ld a,PEN_TEXT
  call text_ink
  ld a,(sel_cmd)
  add a,a
  ld l,a
  ld h,0
  ld de,cmd_names
  add hl,de
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ld c,19
  call hud_print

  call sel_ent
  ld hl,txt_dead
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.mode
  ld hl,txt_truck
  bit EF_BOARDED,(ix+ent.flags)
  jr nz,.mode
  ld hl,txt_drag
  ld a,(ix+ent.drag)
  or a
  jr nz,.mode
  ld hl,txt_crawl
  bit EF_CRAWL,(ix+ent.flags)
  jr nz,.mode
  ld hl,txt_stand
.mode:
  ld c,20
  call hud_print

  ; weapon line
  ld a,(sel_cmd)
  ld hl,txt_kit_beret
  or a
  jr z,.kit
  ld hl,txt_kit_marine
  dec a
  jr z,.kit
  ld a,(ammo)                   ; "RIFLE  n ROUNDS"
  call num2
  ld a,(num_buf+1)
  ld (txt_kit_sniper_n),a
  ld hl,txt_kit_sniper
.kit:
  ld c,21
  call hud_print

  ld hl,txt_objective
  ld a,(tower_down)
  or a
  jr z,.obj
  ld hl,txt_objective2
.obj:
  ld c,22
  call hud_print

  ld a,(game_over)
  or a
  jr z,.playing
  ld hl,txt_done
  cp 2
  jr z,.st
  ld hl,txt_failed
  jr .red
.playing:
  ld a,(alarm)
  or a
  ld hl,txt_quiet
  jr z,.st
  ld a,(alarm_secs)             ; "ALARM! nn"
  call num2
  ld hl,(num_buf)
  ld (txt_alarm_n),hl
  ld hl,txt_alarm
.red:
  push hl
  ld a,PEN_RED
  call text_ink
  pop hl
.st:
  ld c,23
  jp hud_print

; A = 0..99 -> num_buf = two ASCII digits (leading zero kept)
num2:
  ld b,'0'-1
.tens:
  inc b
  sub 10
  jr nc,.tens
  add a,'0'+10
  ld c,a
  ld a,b
  ld (num_buf),a
  ld a,c
  ld (num_buf+1),a
  ret

; A = commando index (0..2). Skipped when this buffer already shows the
; same selection highlight and health (cached after the text rows).
hud_portrait:
  ld (hp_idx),a
  call ent_ptr
  ld a,(ix+ent.hp)
  bit EF_DEAD,(ix+ent.flags)
  jr z,.live
  xor a
.live:
  ld c,a                        ; key = health shown + &80 if selected
  ld a,(sel_cmd)
  ld hl,hp_idx
  cp (hl)
  jr nz,.key
  set 7,c
.key:
  ld a,(back_hi)
  cp &C0
  ld hl,hud_cache_c0+HUD_CACHE_ROW*5
  jr z,.buf
  ld hl,hud_cache_80+HUD_CACHE_ROW*5
.buf:
  ld a,(hp_idx)
  add a,l
  ld l,a
  adc a,h
  sub l
  ld h,a
  ld a,(hl)
  cp c
  ret z
  ld (hl),c
  ld a,(hp_idx)
  ld b,a
  add a,a                       ; x = 2 + idx*10
  add a,a
  add a,b
  add a,a
  add a,2
  ld (hp_x),a
  ; frame colour: yellow if selected, panel blue otherwise
  ld a,(sel_cmd)
  cp b
  ld a,PEN_YELLOW
  jr z,.sel
  ld a,PEN_HUD
.sel:
  call pen_byte
  ld (hp_frame),a
  ld a,(hp_x)
  dec a
  ld b,a
  ld c,PORTRAIT_Y-1
  ld d,PORTRAIT_W+2
  ld e,PORTRAIT_H+2
  ld a,(hp_frame)
  call fill_rect
  ; portrait image
  ld a,(hp_idx)
  ld l,a
  ld h,0
  add hl,hl                     ; * 192
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ld d,h
  ld e,l
  add hl,hl
  add hl,de
  ld de,portrait
  add hl,de
  push hl
  ld a,(hp_x)
  ld b,a
  ld c,PORTRAIT_Y
  call scr_addr
  pop hl
  ld b,PORTRAIT_W
  ld c,PORTRAIT_H
  call blit_plain
  ; health bar under the portrait: green = alive hp, dark = lost
  ld a,(hp_idx)
  call ent_ptr
  ld a,(ix+ent.hp)
  bit EF_DEAD,(ix+ent.flags)
  jr z,.alive
  xor a
.alive:
  ld (hp_hp),a
  ld a,PEN_DKBLUE
  call pen_byte
  ld e,3
  ld d,PORTRAIT_W
  ld c,PORTRAIT_Y+PORTRAIT_H+3
  push af
  ld a,(hp_x)
  ld b,a
  pop af
  call fill_rect
  ld a,(hp_hp)
  or a
  ret z
  ld d,a
  ld a,6                        ; green
  call pen_byte
  ld e,3
  ld c,PORTRAIT_Y+PORTRAIT_H+3
  push af
  ld a,(hp_x)
  ld b,a
  pop af
  jp fill_rect

; ---------------------------------------------------------------------------
; Primitives (back buffer)
; ---------------------------------------------------------------------------

; A = pen -> A = byte with both pixels in that pen
pen_byte:
  push hl
  push de
  ld e,a
  ld d,0
  ld hl,pen_left
  add hl,de
  ld a,(hl)
  ld hl,pen_right
  add hl,de
  or (hl)
  pop de
  pop hl
  ret

; B = x byte, C = y line -> DE = back buffer address
scr_addr:
  ld l,c
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
  add a,b
  ld e,a
  ret nc
  inc d
  ret

; B = x, C = y, D = width, E = height, A = fill byte
fill_rect:
  ld (.fill+1),a
.line:
  push bc
  push de
  call scr_addr
  pop hl                        ; H = width, L = height
  push hl
  ld b,h
.fill:
  ld a,0
.px:
  ld (de),a
  inc de
  djnz .px
  pop de
  pop bc
  inc c
  dec e
  jr nz,.line
  ret

; HL = source bytes, DE = screen, B = width, C = height (plain copy)
blit_plain:
.row:
  push bc
  push de
  ld c,b
  ld b,0
  ldir
  pop de
  ld a,d
  add a,8
  ld d,a
  and &38
  jr nz,.same
  ld a,e
  add a,SCR_W
  ld e,a
  ld a,d
  adc a,&C0
  ld d,a
.same:
  pop bc
  dec c
  jr nz,.row
  ret

; ---------------------------------------------------------------------------
; Text: 4x8 font, two bytes per character, character-row aligned
; ---------------------------------------------------------------------------

; A = ink pen, paper = (text_paper)
text_ink:
  ld (text_cur_ink),a
  ld e,a
  ld d,0
  ld hl,pen_left
  add hl,de
  ld b,(hl)                     ; ink left
  ld hl,pen_right
  add hl,de
  ld c,(hl)                     ; ink right
  ld a,(text_paper)
  ld e,a
  ld hl,pen_left
  add hl,de
  ld d,(hl)                     ; paper left
  ld hl,pen_right
  ld a,e
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld e,(hl)                     ; paper right
  ; text_pairs[n]: n bit1 = left pixel on, bit0 = right pixel on
  ld hl,text_pairs
  ld a,d
  or e
  ld (hl),a                     ; 00
  inc hl
  ld a,d
  or c
  ld (hl),a                     ; 01
  inc hl
  ld a,b
  or e
  ld (hl),a                     ; 10
  inc hl
  ld a,b
  or c
  ld (hl),a                     ; 11
  ; text_words[v] = the two screen bytes for glyph row nibble v
  ld de,text_words
  ld c,0
.w:
  ld a,c
  rrca
  rrca
  and 3
  ld hl,text_pairs
  add a,l
  ld l,a
  ld a,(hl)
  ld (de),a
  inc de
  ld a,c
  and 3
  ld hl,text_pairs
  add a,l
  ld l,a
  ld a,(hl)
  ld (de),a
  inc de
  inc c
  bit 4,c
  jr z,.w
  ret

; HL = string, C = HUD row (19..23): print it at TEXT_X. Only characters
; that differ from what this buffer shows get drawn (the cache keeps the
; whole line, including any tail left by a longer earlier string).
hud_print:
  push hl
  call hud_cache_ptr            ; DE = cache entry (ink, text...)
  pop hl
  ld a,(de)
  ld b,a
  ld a,(text_cur_ink)
  cp b
  jr nz,.full
  inc de
  ld b,TEXT_X
.ch:
  ld a,(hl)
  or a
  jr z,.end
  ex de,hl
  cp (hl)
  ex de,hl
  jr z,.same
  ld (de),a
  push hl
  push de
  push bc
  call print_char
  pop bc
  pop de
  pop hl
.same:
  inc hl
  inc de
  inc b
  inc b
  jr .ch
.end:
  ld (de),a
  ret
.full:                          ; new ink: everything
  ld (de),a
  inc de
  push hl
  ld b,HUD_CACHE_ROW-1
.copy:
  ld a,(hl)
  ld (de),a
  inc hl
  inc de
  or a
  jr z,.copied
  djnz .copy
.copied:
  pop hl
  ld b,TEXT_X
  jp print_at

; C = HUD row -> DE = this back buffer's cache entry for it
hud_cache_ptr:
  ld a,c
  sub 19
  ld l,a                        ; * HUD_CACHE_ROW (32)
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ld a,(back_hi)
  cp &C0
  ld de,hud_cache_c0
  jr z,.b
  ld de,hud_cache_80
.b:
  add hl,de
  ex de,hl
  ret

; Forget what this back buffer shows (after repainting the panel).
hud_cache_clear:
  ld a,(back_hi)
  cp &C0
  ld hl,hud_cache_c0
  jr z,.b
  ld hl,hud_cache_80
.b:
  ld b,HUD_CACHE_SIZE
.lp:
  ld (hl),&FF
  inc hl
  djnz .lp
  ret

; HL = 0-terminated string, B = x byte, C = character row
print_at:
.ch:
  ld a,(hl)
  or a
  ret z
  inc hl
  push hl
  push bc
  call print_char
  pop bc
  pop hl
  inc b
  inc b
  jr .ch

; A = ASCII, B = x byte, C = character row (ink from text_ink)
print_char:
  push bc
  call glyph_index              ; trashes BC
  pop bc
  ld l,a                        ; glyph = font + index*8
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  ld de,font
  add hl,de
  push hl
  call tile_screen_addr_x       ; DE = screen for (B bytes, row C)
  pop hl
  ld b,text_words>>8
  repeat 8,line
  ld a,(hl)                     ; row nibble -> text_words entry
  inc hl
  add a,a
  add a,text_words and &FF      ; table is 32-byte aligned: no carry
  ld c,a
  ld a,(bc)
  ld (de),a
  inc c
  inc e
  ld a,(bc)
  ld (de),a
  dec e
  if line<8
  ld a,d
  add a,8
  ld d,a
  endif
  rend
  ret

; HL = string, C = character row: print centred
print_center:
  push hl
  ld b,0
.len:
  ld a,(hl)
  or a
  jr z,.got
  inc hl
  inc b
  jr .len
.got:
  ld a,SCR_W/2                  ; x = 40 - len (each glyph is 2 bytes)
  sub b
  and &FE
  ld b,a
  pop hl
  jp print_at

; B = x byte, C = character row -> DE (like tile_screen_addr but byte x)
tile_screen_addr_x:
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
  ld a,e
  add a,b
  ld e,a
  ret nc
  inc d
  ret

; A = ASCII -> A = glyph index in the font (see assets/ui/font_chars.txt)
glyph_index:
  cp 'A'
  jr c,.notalpha
  cp 'Z'+1
  jr nc,.space
  sub 'A'-11
  ret
.notalpha:
  cp '0'
  jr c,.punct
  cp '9'+1
  jr nc,.punct
  sub '0'-1
  ret
.punct:
  ld hl,glyph_punct
  ld b,a
  ld c,37
.p:
  ld a,(hl)
  or a
  jr z,.space
  cp b
  ld a,c
  ret z
  inc hl
  inc c
  jr .p
.space:
  xor a
  ret

glyph_punct:
  db ".:!?-/%()',>",0

cmd_names:
  dw txt_beret, txt_marine, txt_sniper
txt_beret:      db "TINY - GREEN BERET    ",0
txt_marine:     db "FINS - MARINE         ",0
txt_sniper:     db "DUKE - SNIPER         ",0
txt_stand:      db "STANDING     ",0
txt_crawl:      db "CRAWLING     ",0
txt_dead:       db "K.I.A.       ",0
txt_truck:      db "IN THE TRUCK ",0
txt_drag:       db "DRAGGING     ",0
txt_kit_beret:  db "KNIFE  DECOY  ",0
txt_kit_marine: db "HARPOON  SCUBA",0
txt_kit_sniper: db "RIFLE  "
txt_kit_sniper_n: db "5 SHOTS",0
txt_objective:  db "DESTROY RADIO TOWER",0
txt_objective2: db "GET TO THE TRUCK!  ",0
txt_quiet:      db "ALL QUIET       ",0
txt_alarm:      db "ALARM! "
txt_alarm_n:    db "60      ",0
txt_done:       db "MISSION COMPLETE",0
txt_failed:     db "MISSION FAILED  ",0
