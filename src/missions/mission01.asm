; ===========================================================================
; Mission 1: "Baptism of Fire" (Norway)
; Snow valley, frozen river, guard outpost, security gate, radio tower.
; Map source: assets/maps/mission01.txt (tile col c -> x = c*4+2,
; tile row r -> feet y = r*8+7)
; ===========================================================================

; Entity spawn records: type, x, y, dir, gfx, bank, hp, route (guards) or
; role (commandos)
; descriptor first: mission_select copies it into mis
m01_desc:
  dw m01_spawns, map_mission01
  db M01_CAM_X, M01_CAM_Y
  db M01_TOWER_COL, M01_TOWER_ROW, 2, 4, M01_TOWER_X, M01_TOWER_Y
  dw m01_ruin
  db M01_TRUCK_X0, M01_TRUCK_X1, M01_TRUCK_Y0, M01_TRUCK_Y1
  dw m01_txt_name, m01_txt_brief, m01_txt_hud1, m01_txt_hud2, m01_txt_obj
  db M01_GUARDS
  dw m01_briefing
  db MAP01_BANK
  dw 0                          ; no HUD tips
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

m01_spawns:
  ; commandos (entities 0..2)
  db ET_COMMANDO, 18, 239, DIR_N : dw spr_beret : db &C4, 8 : dw ROLE_BERET
  db ET_COMMANDO, 26, 247, DIR_N : dw spr_marine : db &C5, 8 : dw ROLE_MARINE
  db ET_COMMANDO, 10, 247, DIR_N : dw spr_sniper : db &C5, 8 : dw ROLE_SNIPER
  ; sentries (entities 3..7)
  db ET_GUARD,  98, 151, DIR_E : dw spr_guard : db &C4, 0 : dw route_bridge
  db ET_GUARD, 122, 111, DIR_S : dw spr_guard : db &C4, 0 : dw route_gate
  db ET_GUARD,  94,  63, DIR_S : dw spr_guard : db &C4, 0 : dw route_barracks
  db ET_GUARD, 138,  63, DIR_E : dw spr_guard : db &C4, 0 : dw route_tower
  db ET_GUARD,  18, 119, DIR_E : dw spr_guard : db &C4, 0 : dw route_river
  ; explosive barrels: one in the compound (too far from the tower: drag
  ; it closer), one by the gate
  db ET_BARREL, 126, 63, DIR_S : dw spr_fx : db &C4, 0 : dw 0
  db ET_BARREL, 114, 108, DIR_S : dw spr_fx : db &C4, 0 : dw 0
  db &FF

; Patrol routes: (x, y, pause ticks) ... &FF
route_bridge:
  db 98, 151, 40
  db 114, 151, 40
  db &FF
route_gate:
  db 122, 111, 60
  db 134, 111, 60
  db &FF
route_barracks:
  db 94, 63, 20
  db 94, 87, 20
  db 118, 87, 30
  db 118, 55, 20
  db 94, 55, 20
  db &FF
route_tower:
  db 138, 63, 50
  db 150, 63, 50
  db &FF
route_river:
  db 18, 119, 30
  db 58, 119, 30
  db &FF

M01_CAM_X       equ 0
M01_CAM_Y       equ CAM_MAX_Y

M01_GUARDS      equ 5
M01_TOWER_COL   equ 35          ; 2x4 tower stamp, top-left tile
M01_TOWER_ROW   equ 3
M01_TOWER_X     equ M01_TOWER_COL*4+4       ; base of the tower (world)
M01_TOWER_Y     equ (M01_TOWER_ROW+4)*8-2
M01_TRUCK_X0    equ 35*4        ; truck footprint (world), cols 35-37 rows 27-28
M01_TRUCK_X1    equ 38*4-1
M01_TRUCK_Y0    equ 27*8
M01_TRUCK_Y1    equ 29*8-1
