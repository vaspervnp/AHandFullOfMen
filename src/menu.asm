; ===========================================================================
; Title menu: banner graphic, mission briefing line and the full list of
; keyboard shortcuts. Fire / Space starts the mission.
; Drawn once into the &C000 buffer, which is then displayed.
; ===========================================================================

MENU_PAPER      equ PEN_DKBLUE
MENU_PROMPT_ROW equ 11

menu_run:
  call palette_black
  ld a,&C0
  ld (back_hi),a
  ld bc,&BC0C                   ; display &C000
  out (c),c
  ld bc,&BD30
  out (c),c
  ; background
  ld a,MENU_PAPER
  call pen_byte
  ld bc,0
  ld de,SCR_W*256+200
  call fill_rect
  ; banner across the top 56 lines
  ld bc,0
  call scr_addr
  ld hl,title_gfx
  ld bc,SCR_W*256+56
  call blit_plain
  ; text
  ld a,MENU_PAPER
  ld (text_paper),a
  ld hl,menu_lines
.line:
  ld a,(hl)                     ; row, &FF ends
  cp &FF
  jr z,.drawn
  ld c,a
  inc hl
  ld a,(hl)                     ; ink
  inc hl
  push hl
  push bc
  call text_ink
  pop bc
  pop hl
  push hl
  call print_center
  pop hl
.skip:                          ; to the byte after the string
  ld a,(hl)
  inc hl
  or a
  jr nz,.skip
  jr .line
.drawn:
  call wait_vsync
  ld hl,pal_norway
  call palette_set
  xor a
  ld (menu_blink),a

.loop:
  call wait_frame
  call kbd_scan
  call joy_read
  if TEST
  call test_input
  endif
  ; blink the start prompt
  ld hl,menu_blink
  inc (hl)
  ld a,(hl)
  and 7
  jr nz,.input
  ld a,(hl)
  and 8
  ld a,PEN_YELLOW
  jr z,.ink
  ld a,PEN_SNOW
.ink:
  call text_ink
  ld hl,txt_menu_start
  ld c,MENU_PROMPT_ROW
  call print_center
.input:
  call joy_fire_hit
  ret nz
  jr .loop

; row, ink, text
menu_lines:
  db 8,  PEN_YELLOW, "MISSION 1: BAPTISM OF FIRE",0
  db 9,  PEN_SNOW,   "NORWAY - DESTROY THE RADIO TOWER",0
  db MENU_PROMPT_ROW, PEN_YELLOW
txt_menu_start:
  db "PRESS SPACE OR FIRE TO START",0
  db 13, PEN_RED,    "- KEYBOARD CONTROLS -",0
  db 15, PEN_TEXT,   "CURSOR KEYS / QAOP  MOVE CROSSHAIR ",0
  db 16, PEN_TEXT,   "SPACE / COPY / FIRE SELECT, GO, KILL",0
  db 17, PEN_TEXT,   "RETURN / C          CRAWL OR STAND  ",0
  db 18, PEN_TEXT,   "1  2  3             PICK COMMANDO   ",0
  db 19, PEN_TEXT,   "SCREEN EDGE         SCROLL THE MAP  ",0
  db 20, PEN_TEXT,   "ESC                 BACK TO MENU    ",0
  db 22, PEN_SNOW,   "JOYSTICK WORKS TOO. STAY OUT OF SIGHT!",0
  db 24, PEN_SNOW,   "REVIVE8BIT 2026",0
  db &FF
