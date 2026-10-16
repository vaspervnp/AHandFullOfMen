; ===========================================================================
; Mission 6: "Heavy Water" (Norway, a hydro plant above a gorge)
; The heavy water plant inside a fenced compound east of a river gorge, a
; wooden bridge and a frozen stretch to cross it, fuel barrels in a far
; corner of the compound, the truck on the west bank. Squad: Green Beret,
; Sniper, Spy. The barrels are too far from the plant: drag one over.
; Map source: assets/maps/mission06.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

; descriptor first: mission_select copies it into mis
m06_desc:
  dw m06_spawns, map_mission06
  db M06_CAM_X, M06_CAM_Y
  db M06_PLANT_COL, M06_PLANT_ROW, 4, 3, M06_PLANT_X, M06_PLANT_Y
  dw m06_ruin
  db M06_TRUCK_X0, M06_TRUCK_X1, M06_TRUCK_Y0, M06_TRUCK_Y1
  dw m06_txt_name, m06_txt_brief, m06_txt_hud1, m06_txt_hud2, m06_txt_obj
  db M06_GUARDS
  dw m06_briefing
m06_ruin:                       ; the plant in ruins
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_RUBBLE
  db TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH
m06_txt_name:  db "MISSION 6: HEAVY WATER",0
m06_txt_brief: db "VEMORK - WRECK THE PLANT",0
m06_txt_hud1:  db "WRECK THE PLANT    ",0
m06_txt_hud2:  db "GET TO THE TRUCK!  ",0
m06_txt_obj:   db "DESTROY HEAVY WATER PLANT ",0
m06_briefing:
  db 11, PEN_RED,  "- OBJECTIVES -",0
  db 12, PEN_TEXT, "THE BARRELS ARE TOO FAR FROM THE",0
  db 13, PEN_TEXT, "PLANT: DRAG ONE OVER AND SHOOT IT",0
  db 14, PEN_TEXT, "THEN RUN FOR THE TRUCK, WEST BANK",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "TINY     KNIFE  D DECOY  G DRAG   ",0
  db 18, PEN_TEXT, "DUKE     RIFLE: 5 SHOTS, LOUD     ",0
  db 19, PEN_TEXT, "SPOOKY   SYRINGE  D UNIFORM G TALK",0
  db 21, PEN_SNOW, "THE BLAST RAISES THE ALARM: 60 S",0
  db &FF

m06_spawns:
  db ET_COMMANDO, 10, 247, DIR_N : dw spr_beret : db RAM_SPRITES, 8 : dw ROLE_BERET
  db ET_COMMANDO, 14, 247, DIR_N : dw spr_sniper : db &C5, 8 : dw ROLE_SNIPER
  db ET_COMMANDO, 18, 247, DIR_N : dw spr_spy : db RAM_BANK6, 8 : dw ROLE_SPY
  db ET_GUARD,  66, 143, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_west
  db ET_GUARD,  82, 199, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_east
  db ET_GUARD, 114, 127, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_gate
  db ET_GUARD,  98,  47, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_plant
  db ET_GUARD, 130, 111, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_store
  db ET_GUARD,  82,  31, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_ice
  db ET_GUARD,  26,  47, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m06_route_road
  ; fuel barrels in the far corner of the compound
  db ET_BARREL, 146, 111, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db ET_BARREL, 150, 103, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db &FF

m06_route_west:                 ; west end of the bridge
  db 66, 143, 40
  db 66, 199, 40
  db &FF
m06_route_east:                 ; east end of the bridge
  db 82, 199, 40
  db 82, 143, 40
  db &FF
m06_route_gate:                 ; outside the gate
  db 114, 127, 50
  db 138, 127, 50
  db &FF
m06_route_plant:                ; round the plant
  db 98, 47, 20
  db 126, 47, 20
  db 126, 87, 20
  db 98, 87, 20
  db &FF
m06_route_store:                ; by the barrels
  db 130, 111, 40
  db 130, 95, 40
  db &FF
m06_route_ice:                  ; east of the frozen stretch
  db 82, 31, 30
  db 110, 31, 30
  db &FF
m06_route_road:                 ; the road south of the truck
  db 26, 47, 40
  db 26, 111, 40
  db &FF

M06_CAM_X       equ 0
M06_CAM_Y       equ CAM_MAX_Y
M06_GUARDS      equ 7
M06_PLANT_COL   equ 26          ; 4x3 plant stamp, top-left tile
M06_PLANT_ROW   equ 6
M06_PLANT_X     equ M06_PLANT_COL*4+8       ; centre of its base (world)
M06_PLANT_Y     equ (M06_PLANT_ROW+3)*8-2
M06_TRUCK_X0    equ 1*4         ; truck: cols 1-3, rows 1-2; board from row 3 too
M06_TRUCK_X1    equ 4*4-1
M06_TRUCK_Y0    equ 1*8
M06_TRUCK_Y1    equ 4*8-1
