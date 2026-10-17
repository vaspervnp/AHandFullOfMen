; ===========================================================================
; Mission 2: "Inferno" (Norway, a fjord fuel depot)
; Fenced compound with the depot between two barracks, a gate on the south
; road, a frozen river with two bridges and an ice crossing, the escape
; truck at the north-west end of the road. Squad: Green Beret, Sapper, Spy.
; Map source: assets/maps/mission02.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

; descriptor first: mission_select copies it into mis
m02_desc:
  dw m02_spawns, map_mission02
  db M02_CAM_X, M02_CAM_Y
  db M02_DEPOT_COL, M02_DEPOT_ROW, 3, 2, M02_DEPOT_X, M02_DEPOT_Y
  dw m02_ruin
  db M02_TRUCK_X0, M02_TRUCK_X1, M02_TRUCK_Y0, M02_TRUCK_Y1
  dw m02_txt_name, m02_txt_brief, m02_txt_hud1, m02_txt_hud2, m02_txt_obj
  db M02_GUARDS
  dw m02_briefing
  db MAP02_BANK
  dw 0                          ; no HUD tips
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

m02_spawns:
  db ET_COMMANDO, 10, 239, DIR_N : dw spr_beret : db RAM_SPRITES, 8 : dw ROLE_BERET
  db ET_COMMANDO, 18, 247, DIR_N : dw spr_sapper : db RAM_BANK6, 8 : dw ROLE_SAPPER
  db ET_COMMANDO,  6, 247, DIR_N : dw spr_spy : db RAM_BANK6, 8 : dw ROLE_SPY
  db ET_GUARD, 98, 127, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_gate
  db ET_GUARD, 14, 127, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_bridge
  db ET_GUARD, 82,  47, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_depot
  db ET_GUARD, 98, 103, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_barracks
  db ET_GUARD, 26, 175, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_river
  db ET_GUARD, 110, 191, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_road
  db ET_GUARD, 126,  39, DIR_W : dw spr_guard : db RAM_SPRITES, 0 : dw m02_route_watch
  db &FF

m02_route_gate:                 ; paces in front of the gate
  db 98, 127, 60
  db 110, 127, 60
  db &FF
m02_route_bridge:               ; north end of the west bridge
  db 14, 127, 40
  db 30, 127, 40
  db &FF
m02_route_depot:                ; round the fuel tanks
  db 82, 47, 20
  db 118, 47, 20
  db 118, 71, 20
  db 82, 71, 20
  db &FF
m02_route_barracks:
  db 98, 103, 30
  db 98, 79, 30
  db &FF
m02_route_river:
  db 26, 175, 30
  db 70, 175, 30
  db &FF
m02_route_road:
  db 110, 191, 40
  db 138, 191, 40
  db &FF
m02_route_watch:                ; the north-east corner of the compound
  db 126, 39, 80
  db 126, 63, 80
  db &FF

M02_CAM_X       equ 0
M02_CAM_Y       equ CAM_MAX_Y
M02_GUARDS      equ 7
M02_DEPOT_COL   equ 23          ; 3x2 depot stamp, top-left tile
M02_DEPOT_ROW   equ 6
M02_DEPOT_X     equ M02_DEPOT_COL*4+6       ; centre of its base (world)
M02_DEPOT_Y     equ (M02_DEPOT_ROW+2)*8-2
M02_TRUCK_X0    equ 0           ; truck: cols 0-2, rows 0-1; board from row 2 too
M02_TRUCK_X1    equ 3*4-1
M02_TRUCK_Y0    equ 0
M02_TRUCK_Y1    equ 3*8-1       ; (the map edge keeps feet off rows 0-1)
