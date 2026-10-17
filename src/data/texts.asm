; ===========================================================================
; Constant data kept in the &4000 data area (the code area is full): HUD
; and menu texts, the cone's sine table. None of it is read while a sprite
; bank is paged in.
; ===========================================================================

; --- HUD (src/render/hud.asm)
role_texts:                     ; per ROLE_*: name, kit
  dw txt_beret, txt_kit_beret
  dw txt_marine, txt_kit_marine
  dw txt_sniper, txt_kit_sniper
  dw txt_sapper, txt_kit_sapper
  dw txt_spy, txt_kit_spy
txt_beret:      db "TINY - GREEN BERET    ",0
txt_marine:     db "FINS - MARINE         ",0
txt_sniper:     db "DUKE - SNIPER         ",0
txt_sapper:     db "INFERNO - SAPPER      ",0
txt_spy:        db "SPOOKY - SPY          ",0
txt_disguised:  db "IN UNIFORM   ",0
txt_kit_sapper: db "TRAPS "
txt_kit_sapper_t: db "2  BOMB "
txt_kit_sapper_b: db "1",0
txt_kit_spy:    db "SYRINGE  TALK  ",0
txt_stand:      db "STANDING     ",0
txt_crawl:      db "CRAWLING     ",0
txt_dead:       db "K.I.A.       ",0
txt_truck:      db "IN THE TRUCK ",0
txt_drag:       db "DRAGGING     ",0
txt_kit_beret:  db "KNIFE  DECOY   ",0
txt_kit_marine: db "HARPOON  SCUBA ",0
txt_kit_sniper: db "RIFLE  "
txt_kit_sniper_n: db "5 SHOTS ",0
txt_quiet:      db "ALL QUIET       ",0
txt_alarm:      db "ALARM! "
txt_alarm_n:    db "60      ",0
txt_done:       db "MISSION COMPLETE",0
txt_failed:     db "MISSION FAILED  ",0

; --- menu and debrief (src/menu.asm)

; row, ink, text
menu_lines:
  db 10, PEN_TEXT,   "STICK OR 1-7: MISSION, 0: TRAINING",0
  db 13, PEN_RED,    "- KEYBOARD CONTROLS -",0
  db 15, PEN_TEXT,   "CURSOR KEYS / QAOP  MOVE CROSSHAIR ",0
  db 16, PEN_TEXT,   "SPACE / COPY / FIRE SELECT,GO,ATTACK",0
  db 17, PEN_TEXT,   "RETURN / C          CRAWL OR STAND  ",0
  db 18, PEN_TEXT,   "1  2  3             PICK COMMANDO   ",0
  db 19, PEN_TEXT,   "D   G               ROLE ABILITIES  ",0
  db 20, PEN_TEXT,   "V  (OR POINT AT)    GUARD VIEW CONE ",0
  db 21, PEN_TEXT,   "SCREEN EDGE         SCROLL THE MAP  ",0
  db 22, PEN_TEXT,   "ESC                 BACK TO MENU    ",0
  db 24, PEN_SNOW,   "REVIVE8BIT 2026",0
  db &FF
txt_brief_go:
  db "PRESS SPACE OR FIRE TO GO IN",0
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

; --- vision cone (src/render/vision_cone.asm)
; sin(a * 2pi / 256) * 127
sin_tab:
  db 0,3,6,9,12,16,19,22,25,28,31,34,37,40,43,46
  db 49,51,54,57,60,63,65,68,71,73,76,78,81,83,85,88
  db 90,92,94,96,98,100,102,104,106,107,109,111,112,113,115,116
  db 117,118,120,121,122,122,123,124,125,125,126,126,126,127,127,127
  db 127,127,127,127,126,126,126,125,125,124,123,122,122,121,120,118
  db 117,116,115,113,112,111,109,107,106,104,102,100,98,96,94,92
  db 90,88,85,83,81,78,76,73,71,68,65,63,60,57,54,51
  db 49,46,43,40,37,34,31,28,25,22,19,16,12,9,6,3
  db 0,-3,-6,-9,-12,-16,-19,-22,-25,-28,-31,-34,-37,-40,-43,-46
  db -49,-51,-54,-57,-60,-63,-65,-68,-71,-73,-76,-78,-81,-83,-85,-88
  db -90,-92,-94,-96,-98,-100,-102,-104,-106,-107,-109,-111,-112,-113,-115,-116
  db -117,-118,-120,-121,-122,-122,-123,-124,-125,-125,-126,-126,-126,-127,-127,-127
  db -127,-127,-127,-127,-126,-126,-126,-125,-125,-124,-123,-122,-122,-121,-120,-118
  db -117,-116,-115,-113,-112,-111,-109,-107,-106,-104,-102,-100,-98,-96,-94,-92
  db -90,-88,-85,-83,-81,-78,-76,-73,-71,-68,-65,-63,-60,-57,-54,-51
  db -49,-46,-43,-40,-37,-34,-31,-28,-25,-22,-19,-16,-12,-9,-6,-3
