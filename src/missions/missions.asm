; ===========================================================================
; Mission table (data area). mission_begin (src/game.asm) copies the chosen
; descriptor into mis and loads its map and spawn list; the rest of the game
; only reads mis.
; ===========================================================================

; descriptor fields: MIS_* in src/defs.asm
MISSION_COUNT   equ 2

mission_table:
  dw m01_desc, m02_desc

; ---------------------------------------------------------------------------
; Mission 1: Baptism of Fire
; ---------------------------------------------------------------------------
m01_desc:
  dw m01_spawns, map_mission01
  db M01_CAM_X, M01_CAM_Y
  db M01_TOWER_COL, M01_TOWER_ROW, 2, 4, M01_TOWER_X, M01_TOWER_Y
  dw m01_ruin
  db M01_TRUCK_X0, M01_TRUCK_X1, M01_TRUCK_Y0, M01_TRUCK_Y1
  dw m01_txt_name, m01_txt_brief, m01_txt_hud1, m01_txt_hud2, m01_txt_obj
  db M01_GUARDS
  dw m01_briefing
m01_ruin:                       ; the tower: top half snow, base rubble
  db TILE_SNOW, TILE_SNOW, TILE_SNOW, TILE_SNOW
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH
m01_txt_name:  db "MISSION 1: BAPTISM OF FIRE",0
m01_txt_brief: db "NORWAY - DESTROY THE RADIO TOWER",0
m01_txt_hud1:  db "DESTROY RADIO TOWER",0
m01_txt_hud2:  db "GET TO THE TRUCK!  ",0
m01_txt_obj:   db "DESTROY THE RADIO TOWER   ",0
m01_briefing:                   ; row, ink, text (page_lines)
  db 11, PEN_RED,  "- OBJECTIVES -",0
  db 12, PEN_TEXT, "BRING DOWN THE RADIO TOWER: A SHOT",0
  db 13, PEN_TEXT, "BARREL RIGHT NEXT TO IT WILL DO",0
  db 14, PEN_TEXT, "THEN GET THE SQUAD INTO THE TRUCK",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "TINY   KNIFE   D DECOY   G DRAG ",0
  db 18, PEN_TEXT, "FINS   HARPOON   SWIMS UNSEEN   ",0
  db 19, PEN_TEXT, "DUKE   RIFLE: 5 SHOTS, LOUD     ",0
  db 21, PEN_SNOW, "AFTER AN ALARM: 60 SECONDS TO GO",0
  db &FF

; ---------------------------------------------------------------------------
; Mission 2: Inferno
; ---------------------------------------------------------------------------
m02_desc:
  dw m02_spawns, map_mission02
  db M02_CAM_X, M02_CAM_Y
  db M02_DEPOT_COL, M02_DEPOT_ROW, 3, 2, M02_DEPOT_X, M02_DEPOT_Y
  dw m02_ruin
  db M02_TRUCK_X0, M02_TRUCK_X1, M02_TRUCK_Y0, M02_TRUCK_Y1
  dw m02_txt_name, m02_txt_brief, m02_txt_hud1, m02_txt_hud2, m02_txt_obj
  db M02_GUARDS
  dw m02_briefing
m02_ruin:                       ; burnt-out tanks
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE
  db TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH
m02_txt_name:  db "MISSION 2: INFERNO",0
m02_txt_brief: db "FJORD DEPOT - BLOW UP THE FUEL",0
m02_txt_hud1:  db "BLOW UP FUEL DEPOT ",0
m02_txt_hud2:  db "GET TO THE TRUCK!  ",0
m02_txt_obj:   db "BLOW UP THE FUEL DEPOT    ",0
m02_briefing:
  db 11, PEN_RED,  "- OBJECTIVES -",0
  db 12, PEN_TEXT, "PLANT THE TIME BOMB BY THE FUEL",0
  db 13, PEN_TEXT, "TANKS INSIDE THE COMPOUND, RUN,",0
  db 14, PEN_TEXT, "THEN TAKE THE TRUCK UP NORTH",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "TINY     KNIFE  D DECOY  G DRAG   ",0
  db 18, PEN_TEXT, "INFERNO  D BEAR TRAP  G TIME BOMB ",0
  db 19, PEN_TEXT, "SPOOKY   SYRINGE  D UNIFORM G TALK",0
  db 21, PEN_SNOW, "THE BOMB RAISES THE ALARM: 60 S",0
  db &FF
