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
  ld b,TEXT_X
  ld c,19
  call print_at

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
  ld b,TEXT_X
  ld c,20
  call print_at

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
  ld b,TEXT_X
  ld c,21
  call print_at

  ld hl,txt_objective
  ld a,(tower_down)
  or a
  jr z,.obj
  ld hl,txt_objective2
.obj:
  ld b,TEXT_X
  ld c,22
  call print_at

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
  ld b,TEXT_X
  ld c,23
  jp print_at

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

; A = commando index (0..2)
hud_portrait:
  ld (hp_idx),a
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
  call glyph_index              ; trashes BC
  pop bc
  push bc
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
  ld b,8
.line:
  push hl
  ld a,(hl)
  rrca
  rrca
  and 3
  call text_pair
  ld (de),a
  inc e
  pop hl
  ld a,(hl)
  and 3
  push hl
  call text_pair
  ld (de),a
  dec e
  pop hl
  inc hl
  ld a,d
  add a,8
  ld d,a
  djnz .line
  pop bc
  pop hl
  inc b
  inc b
  jr .ch

text_pair:
  push hl
  ld hl,text_pairs
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld a,(hl)
  pop hl
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
