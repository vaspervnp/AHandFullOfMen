; ===========================================================================
; Full-screen pages on the &C000 buffer: the title menu (banner, mission
; line, keyboard shortcuts) and the end-of-mission debrief.
; ===========================================================================

MENU_PAPER      equ PEN_DKBLUE
MENU_PROMPT_ROW equ 11
DEBRIEF_PROMPT_ROW equ 23

menu_run:
  call mission_select
  call page_begin
  call menu_mission
  ld hl,menu_lines
  call page_lines
  ld hl,menu_keys
  ld (page_hook),hl
  ld hl,song_title
  call music_start
  ld hl,txt_menu_start
  ld c,MENU_PROMPT_ROW
  jp page_wait_fire

; Briefing page for (mis): objectives and what the squad can do.
briefing_run:
  call page_begin
  call menu_mission
  ld hl,(mis+MIS_BRIEFING)
  call page_lines
  ld hl,txt_brief_go
  ld c,MENU_PROMPT_ROW+12
  jp page_wait_fire

; Mission name + briefing (rows 8, 9) for (cur_mission).
menu_mission:
  ld b,8
  call page_clear_row
  ld b,9
  call page_clear_row
  ld a,PEN_YELLOW
  call text_ink
  ld hl,(mis+MIS_TXT_NAME)
  ld c,8
  call print_center
  ld a,PEN_SNOW
  call text_ink
  ld hl,(mis+MIS_TXT_BRIEF)
  ld c,9
  jp print_center

; B = character row: paint it with the page colour
page_clear_row:
  ld a,b
  add a,a
  add a,a
  add a,a
  ld c,a
  ld a,MENU_PAPER
  call pen_byte
  ld b,0
  ld de,SCR_W*256+8
  jp fill_rect

; Menu keys while waiting: 1 .. 7 choose the mission.
menu_keys:
  ld a,KEY_1
  call kbd_hit
  ld a,0
  jr nz,.pick
  ld a,KEY_2
  call kbd_hit
  ld a,1
  jr nz,.pick
  ld a,KEY_3
  call kbd_hit
  ld a,2
  jr nz,.pick
  ld a,KEY_4
  call kbd_hit
  ld a,3
  jr nz,.pick
  ld a,KEY_5
  call kbd_hit
  ld a,4
  jr nz,.pick
  ld a,KEY_6
  call kbd_hit
  ld a,5
  jr nz,.pick
  ld a,KEY_7
  call kbd_hit
  ret z
  ld a,6
.pick:
  cp MISSION_COUNT
  ret nc
  ld (cur_mission),a
  call mission_select
  jp menu_mission

; Debrief: result, reason, objective checklist, stats.
debrief_run:
  ld hl,(mis+MIS_TXT_OBJ)       ; this mission's objective + sentries
  ld de,txt_obj_tower+4
  ld bc,26
  ldir
  ld a,(mis+MIS_GUARDS)
  add a,'0'
  ld (txt_stat_guards_n+4),a
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
  ld a,(target_down)
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
  ld a,(game_over)
  cp 2
  ld hl,song_win
  jr z,.song
  ld hl,song_lose
.song:
  call music_start
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
  ld bc,&7F00+RAM_BANK7          ; the banner lives in bank 7
  out (c),c
  ld hl,title_gfx
  ld bc,SCR_W*256+56
  call blit_plain
  ld bc,&7F00+RAM_BASE64
  out (c),c
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
  call music_update
  call kbd_scan
  call joy_read
  if TEST
  xor a                         ; a script ending here has no view to check
  ld (test_view),a
  call test_input
  endif
  ld hl,(page_hook)             ; page-specific keys (the menu's)
  ld a,h
  or l
  call nz,jp_hl
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
  jr z,.loop
  ld hl,0
  ld (page_hook),hl
  jp music_stop

jp_hl:
  jp (hl)

