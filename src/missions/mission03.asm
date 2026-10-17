; ===========================================================================
; Mission 3: "Rough Waters" (Norway, a harbour)
; A U-boat moored at a wooden pier, fuel barrels stacked beside it, a fenced
; dock yard with one gate on the east road, a canal down the west edge (the
; Marine's way in), the truck south of the gate. Squad: Marine, Sniper, Spy.
; Map source: assets/maps/mission03.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

; descriptor first: mission_select copies it into mis
m03_desc:
  dw m03_spawns, map_mission03
  db M03_CAM_X, M03_CAM_Y
  db M03_UBOAT_COL, M03_UBOAT_ROW, 16, 6, M03_UBOAT_X, M03_UBOAT_Y
  dw m03_ruin
  db M03_TRUCK_X0, M03_TRUCK_X1, M03_TRUCK_Y0, M03_TRUCK_Y1
  dw m03_txt_name, m03_txt_brief, m03_txt_hud1, m03_txt_hud2, m03_txt_obj
  db M03_GUARDS
  dw m03_briefing
  db MAP03_BANK
  dw 0                          ; no HUD tips
m03_ruin:                       ; she sinks
  ds 16*6,TILE_WATER
m03_txt_name:  db "MISSION 3: ROUGH WATERS",0
m03_txt_brief: db "HARBOUR - SINK THE U-BOAT",0
m03_txt_hud1:  db "SINK THE U-BOAT    ",0
m03_txt_hud2:  db "GET TO THE TRUCK!  ",0
m03_txt_obj:   db "SINK THE U-BOAT           ",0
m03_briefing:
  db 11, PEN_RED,  "- OBJECTIVES -",0
  db 12, PEN_TEXT, "SINK THE U-BOAT AT THE PIER: SHOOT",0
  db 13, PEN_TEXT, "THE FUEL BARRELS STACKED BESIDE IT",0
  db 14, PEN_TEXT, "THEN RUN FOR THE TRUCK BY THE ROAD",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "FINS    HARPOON  SWIMS THE CANAL  ",0
  db 18, PEN_TEXT, "DUKE    RIFLE: 5 SHOTS, LOUD      ",0
  db 19, PEN_TEXT, "SPOOKY  SYRINGE  D UNIFORM G TALK ",0
  db 21, PEN_SNOW, "THE BLAST RAISES THE ALARM: 60 S",0
  db &FF

m03_spawns:
  db ET_COMMANDO, 14, 247, DIR_N : dw spr_marine : db &C5, 8 : dw ROLE_MARINE
  db ET_COMMANDO, 22, 247, DIR_N : dw spr_sniper : db &C5, 8 : dw ROLE_SNIPER
  db ET_COMMANDO, 30, 247, DIR_N : dw spr_spy : db RAM_BANK6, 8 : dw ROLE_SPY
  db ET_GUARD, 122, 191, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m03_route_gate
  db ET_GUARD,  78,  95, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m03_route_pier
  db ET_GUARD,  22, 111, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m03_route_shore
  db ET_GUARD,  62, 151, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m03_route_yard
  db ET_GUARD, 146, 127, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m03_route_watch
  db ET_GUARD, 122, 207, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m03_route_road
  ; fuel barrels on the pier, next to the U-boat
  db ET_BARREL, 78, 63, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db ET_BARREL, 74, 55, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db &FF

m03_route_gate:                 ; outside the gate
  db 122, 191, 50
  db 134, 191, 50
  db &FF
m03_route_pier:                 ; up and down the pier
  db 78, 95, 40
  db 78, 39, 40
  db &FF
m03_route_shore:
  db 22, 111, 30
  db 110, 111, 30
  db &FF
m03_route_yard:
  db 62, 151, 30
  db 62, 175, 20
  db 86, 175, 30
  db &FF
m03_route_watch:                ; east of the warehouses
  db 146, 127, 60
  db 146, 159, 60
  db &FF
m03_route_road:                 ; between the gate and the truck
  db 122, 207, 40
  db 122, 239, 40
  db &FF

M03_CAM_X       equ 0
M03_CAM_Y       equ CAM_MAX_Y
M03_GUARDS      equ 6
M03_UBOAT_COL   equ 20          ; 16x6 U-boat stamp, top-left tile
M03_UBOAT_ROW   equ 3
M03_UBOAT_X     equ M03_UBOAT_COL*4+2       ; its pier side (world)
M03_UBOAT_Y     equ (M03_UBOAT_ROW+6)*8-2
M03_TRUCK_X0    equ 35*4        ; truck footprint: cols 35-37, rows 27-28
M03_TRUCK_X1    equ 38*4-1
M03_TRUCK_Y0    equ 27*8
M03_TRUCK_Y1    equ 29*8-1
