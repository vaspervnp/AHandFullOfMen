; ===========================================================================
; Full-screen pages on the &C000 buffer: the title menu (banner, mission
; line, keyboard shortcuts) and the end-of-mission debrief.
; ===========================================================================

MENU_PAPER      equ PEN_DKBLUE
MENU_PROMPT_ROW equ 11
DEBRIEF_PROMPT_ROW equ 23

menu_run:
  call page_begin
  ld hl,menu_lines
  call page_lines
  ld hl,txt_menu_start
  ld c,MENU_PROMPT_ROW
  jp page_wait_fire

; Debrief: result, reason, objective checklist, stats.
debrief_run:
  ; result + reason
  ld a,(game_over)
  cp 2
  ld hl,txt_accomplished
  ld a,PEN_YELLOW
  jr z,.res
  ld hl,txt_mission_failed
  ld a,PEN_RED
.res:
  ld (deb_result_ink),a
  ld (deb_result_ptr),hl
  ld a,(end_reason)
  add a,a
  ld l,a
  ld h,0
  ld de,reason_texts
  add hl,de
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ld (deb_reason_ptr),hl
  ; checklist marks
  ld a,(tower_down)
  ld hl,txt_obj_tower+1
  call set_mark
  ld a,(end_reason)
  cp END_ESCAPED
  ld a,0
  jr nz,.esc
  inc a
.esc:
  ld hl,txt_obj_escape+1
  call set_mark
  ld a,(alarm)
  xor 1
  ld hl,txt_obj_quiet+1
  call set_mark
  ; sentries down / survivors
  ld bc,0                       ; B = guards down, C = commandos alive
  xor a
.count:
  push af
  call ent_ptr
  pop af
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.dead
  cp CMD_COUNT
  jr nc,.nx
  inc c
  jr .nx
.dead:
  ld e,a
  ld a,(ix+ent.type)
  cp ET_GUARD
  ld a,e
  jr nz,.nx
  inc b
.nx:
  inc a
  cp MAX_ENTS
  jr nz,.count
  push bc
  ld a,b
  call num2
  ld a,(num_buf+1)
  ld (txt_stat_guards_n),a
  pop bc
  ld a,c
  call num2
  ld a,(num_buf+1)
  ld (txt_stat_alive_n),a
  ; mission time mm:ss
  ld hl,(mission_secs)
  ld de,60
  ld b,0
.min:
  or a
  sbc hl,de
  jr c,.mdone
  inc b
  ld a,b
  cp 99
  jr nz,.min
.mdone:
  add hl,de
  ld a,l
  push af
  ld a,b
  call num2
  ld hl,(num_buf)
  ld (txt_stat_time_n),hl
  pop af
  call num2
  ld hl,(num_buf)
  ld (txt_stat_time_n+3),hl

  call page_begin
  ld a,(deb_result_ink)
  call text_ink
  ld hl,(deb_result_ptr)
  ld c,8
  call print_center
  ld a,PEN_SNOW
  call text_ink
  ld hl,(deb_reason_ptr)
  ld c,9
  call print_center
  ld hl,debrief_lines
  call page_lines
  ld hl,txt_continue
  ld c,DEBRIEF_PROMPT_ROW
  jp page_wait_fire

; A = 0/1 -> (HL) = ' ' or 'X'
set_mark:
  or a
  ld a,' '
  jr z,.m
  ld a,'X'
.m:
  ld (hl),a
  ret

; ---------------------------------------------------------------------------
; Page helpers
; ---------------------------------------------------------------------------

; Blank palette, show &C000, fill it and draw the banner.
page_begin:
  call palette_black
  ld a,&C0
  ld (back_hi),a
  ld bc,&BC0C                   ; display &C000
  out (c),c
  ld bc,&BD30
  out (c),c
  ld a,MENU_PAPER
  call pen_byte
  ld bc,0
  ld de,SCR_W*256+200
  call fill_rect
  ld bc,0
  call scr_addr
  ld hl,title_gfx
  ld bc,SCR_W*256+56
  call blit_plain
  ld a,MENU_PAPER
  ld (text_paper),a
  ret

; HL = list of (row, ink, text, 0) ... &FF, printed centred
page_lines:
.line:
  ld a,(hl)
  cp &FF
  ret z
  ld c,a
  inc hl
  ld a,(hl)
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

; Show the palette, then blink prompt HL on row C until fire / space.
page_wait_fire:
  ld (page_prompt),hl
  ld a,c
  ld (page_prompt_row),a
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
  ld hl,(page_prompt)
  ld a,(page_prompt_row)
  ld c,a
  call print_center
.input:
  call joy_fire_hit
  ret nz
  jr .loop

; ---------------------------------------------------------------------------
; Texts
; ---------------------------------------------------------------------------

; row, ink, text
menu_lines:
  db 8,  PEN_YELLOW, "MISSION 1: BAPTISM OF FIRE",0
  db 9,  PEN_SNOW,   "NORWAY - DESTROY THE RADIO TOWER",0
  db 13, PEN_RED,    "- KEYBOARD CONTROLS -",0
  db 15, PEN_TEXT,   "CURSOR KEYS / QAOP  MOVE CROSSHAIR ",0
  db 16, PEN_TEXT,   "SPACE / COPY / FIRE SELECT,GO,ATTACK",0
  db 17, PEN_TEXT,   "RETURN / C          CRAWL OR STAND  ",0
  db 18, PEN_TEXT,   "1  2  3             PICK COMMANDO   ",0
  db 19, PEN_TEXT,   "D   G               DECOY   DRAG    ",0
  db 20, PEN_TEXT,   "V  (OR POINT AT)    GUARD VIEW CONE ",0
  db 21, PEN_TEXT,   "SCREEN EDGE         SCROLL THE MAP  ",0
  db 22, PEN_TEXT,   "ESC                 BACK TO MENU    ",0
  db 24, PEN_SNOW,   "REVIVE8BIT 2026",0
  db &FF
txt_menu_start:
  db "PRESS SPACE OR FIRE TO START",0

debrief_lines:
  db 12, PEN_RED,    "- OBJECTIVES -",0
  db 14, PEN_TEXT
txt_obj_tower:
  db "( ) DESTROY THE RADIO TOWER   ",0
  db 15, PEN_TEXT
txt_obj_escape:
  db "( ) ESCAPE IN THE TRUCK       ",0
  db 16, PEN_TEXT
txt_obj_quiet:
  db "( ) NO ALARM RAISED  (BONUS)  ",0
  db 18, PEN_SNOW,   "SENTRIES DOWN            "
txt_stat_guards_n:
  db "0 / 5",0
  db 19, PEN_SNOW,   "SQUAD MEMBERS ALIVE      "
txt_stat_alive_n:
  db "0 / 3",0
  db 20, PEN_SNOW,   "MISSION TIME             "
txt_stat_time_n:
  db "00:00",0
  db &FF
txt_continue:
  db "PRESS SPACE OR FIRE",0

txt_accomplished:   db "MISSION ACCOMPLISHED",0
txt_mission_failed: db "MISSION FAILED",0
reason_texts:
  dw txt_reason_lost, txt_reason_reinforced, txt_reason_escaped
txt_reason_lost:       db "THE WHOLE SQUAD WAS LOST",0
txt_reason_reinforced: db "ENEMY REINFORCEMENTS ARRIVED",0
txt_reason_escaped:    db "THE SQUAD GOT AWAY IN THE TRUCK",0
