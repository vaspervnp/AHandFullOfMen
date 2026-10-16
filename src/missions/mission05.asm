; ===========================================================================
; Mission 5: "The Guns of Vardo" (Norway, a coastal battery)
; A big gun in a concrete pit inside a fenced headland battery: one gate on
; the south road, and a gap in the north fence that only a swimmer can
; reach. The truck waits east along the road. Squad: Marine, Sapper, Spy.
; Map source: assets/maps/mission05.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

; descriptor first: mission_select copies it into mis
m05_desc:
  dw m05_spawns, map_mission05
  db M05_CAM_X, M05_CAM_Y
  db M05_GUN_COL, M05_GUN_ROW, 4, 3, M05_GUN_X, M05_GUN_Y
  dw m05_ruin
  db M05_TRUCK_X0, M05_TRUCK_X1, M05_TRUCK_Y0, M05_TRUCK_Y1
  dw m05_txt_name, m05_txt_brief, m05_txt_hud1, m05_txt_hud2, m05_txt_obj
  db M05_GUARDS
  dw m05_briefing
  db MAP05_BANK
m05_ruin:                       ; a burnt-out pit
  db TILE_SNOW, TILE_RUBBLE, TILE_SCORCH, TILE_SNOW
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH
  db TILE_SNOW, TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE
m05_txt_name:  db "MISSION 5: THE GUNS OF VARDO",0
m05_txt_brief: db "COAST - SILENCE THE BIG GUN",0
m05_txt_hud1:  db "DESTROY COASTAL GUN",0
m05_txt_hud2:  db "GET TO THE TRUCK!  ",0
m05_txt_obj:   db "DESTROY THE COASTAL GUN   ",0
m05_briefing:
  db 11, PEN_RED,  "- OBJECTIVES -",0
  db 12, PEN_TEXT, "PLANT THE TIME BOMB BY THE BIG GUN",0
  db 13, PEN_TEXT, "IN THE FENCED BATTERY, THEN TAKE",0
  db 14, PEN_TEXT, "THE TRUCK EAST ALONG THE ROAD",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "FINS     HARPOON  SWIMS UNSEEN    ",0
  db 18, PEN_TEXT, "INFERNO  D BEAR TRAP  G TIME BOMB ",0
  db 19, PEN_TEXT, "SPOOKY   SYRINGE  D UNIFORM G TALK",0
  db 21, PEN_SNOW, "A GAP IN THE FENCE FACES THE SEA",0
  db &FF

m05_spawns:
  db ET_COMMANDO, 42, 247, DIR_N : dw spr_marine : db &C5, 8 : dw ROLE_MARINE
  db ET_COMMANDO, 46, 247, DIR_N : dw spr_sapper : db RAM_BANK6, 8 : dw ROLE_SAPPER
  db ET_COMMANDO, 50, 247, DIR_N : dw spr_spy : db RAM_BANK6, 8 : dw ROLE_SPY
  db ET_GUARD,  62, 135, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_gate
  db ET_GUARD,  46,  55, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_crew
  db ET_GUARD,  42,  63, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_fence
  db ET_GUARD,  82, 111, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_bunker
  db ET_GUARD,  90, 151, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_road
  db ET_GUARD, 130, 127, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_truck
  db ET_GUARD,  50, 167, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m05_route_woods
  db &FF

m05_route_gate:                 ; outside the gate
  db 62, 135, 50
  db 86, 135, 50
  db &FF
m05_route_crew:                 ; the gun crew walks round the pit
  db 46, 55, 20
  db 74, 55, 20
  db 74, 95, 20
  db 46, 95, 20
  db &FF
m05_route_fence:                ; inside the west fence, by the gap
  db 42, 63, 40
  db 42, 111, 40
  db &FF
m05_route_bunker:
  db 82, 111, 30
  db 98, 111, 30
  db &FF
m05_route_road:
  db 90, 151, 40
  db 130, 151, 40
  db &FF
m05_route_truck:
  db 130, 127, 50
  db 130, 103, 50
  db &FF
m05_route_woods:                ; south of the road
  db 50, 167, 30
  db 106, 167, 30
  db &FF

M05_CAM_X       equ 0
M05_CAM_Y       equ CAM_MAX_Y
M05_GUARDS      equ 7
M05_GUN_COL     equ 13          ; 4x3 coastal gun stamp, top-left tile
M05_GUN_ROW     equ 8
M05_GUN_X       equ M05_GUN_COL*4+8         ; centre of its base (world)
M05_GUN_Y       equ (M05_GUN_ROW+3)*8-2
M05_TRUCK_X0    equ 36*4        ; truck: cols 36-38, rows 15-16; board from row 17 too
M05_TRUCK_X1    equ 39*4-1
M05_TRUCK_Y0    equ 15*8
M05_TRUCK_Y1    equ 18*8-1
