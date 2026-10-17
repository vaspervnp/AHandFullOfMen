; ===========================================================================
; Mission 7: "Night Train" (Norway, a railway station)
; An ammunition train stands on the main line inside the station yard,
; fenced north and south with a gate in each fence; a fuel barrel stands
; beside the middle wagon. The truck is beyond the south gate. Squad:
; Sniper, Sapper, Spy.
; Map source: assets/maps/mission07.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

; descriptor first: mission_select copies it into mis
m07_desc:
  dw m07_spawns, map_mission07
  db M07_CAM_X, M07_CAM_Y
  db M07_TRAIN_COL, M07_TRAIN_ROW, 10, 3, M07_TRAIN_X, M07_TRAIN_Y
  dw m07_ruin
  db M07_TRUCK_X0, M07_TRUCK_X1, M07_TRUCK_Y0, M07_TRUCK_Y1
  dw m07_txt_name, m07_txt_brief, m07_txt_hud1, m07_txt_hud2, m07_txt_obj
  db M07_GUARDS
  dw m07_briefing
  db MAP07_BANK
m07_ruin:                       ; twisted wreckage on a scorched track
  db TILE_SNOW, TILE_RUBBLE, TILE_SNOW, TILE_SNOW, TILE_RUBBLE
  db TILE_SNOW, TILE_SNOW, TILE_RUBBLE, TILE_SNOW, TILE_SNOW
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_RUBBLE, TILE_SCORCH
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE
  db TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH, TILE_SCORCH, TILE_RUBBLE
  db TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH
m07_txt_name:  db "MISSION 7: NIGHT TRAIN",0
m07_txt_brief: db "STATION - BLOW UP THE TRAIN",0
m07_txt_hud1:  db "BLOW UP THE TRAIN  ",0
m07_txt_hud2:  db "GET TO THE TRUCK!  ",0
m07_txt_obj:   db "BLOW UP THE AMMO TRAIN    ",0
m07_briefing:
  db 11, PEN_RED,  "- OBJECTIVES -",0
  db 12, PEN_TEXT, "BLOW UP THE AMMUNITION TRAIN: A",0
  db 13, PEN_TEXT, "TIME BOMB, OR A SHOT AT THE BARREL",0
  db 14, PEN_TEXT, "BESIDE IT. TRUCK: PAST SOUTH GATE",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "DUKE     RIFLE: 5 SHOTS, LOUD     ",0
  db 18, PEN_TEXT, "INFERNO  D BEAR TRAP  G TIME BOMB ",0
  db 19, PEN_TEXT, "SPOOKY   SYRINGE  D UNIFORM G TALK",0
  db 21, PEN_SNOW, "THE BLAST RAISES THE ALARM: 60 S",0
  db &FF

m07_spawns:
  db ET_COMMANDO, 10, 23, DIR_S : dw spr_sniper : db &C5, 8 : dw ROLE_SNIPER
  db ET_COMMANDO, 14, 23, DIR_S : dw spr_sapper : db RAM_BANK6, 8 : dw ROLE_SAPPER
  db ET_COMMANDO, 18, 23, DIR_S : dw spr_spy : db RAM_BANK6, 8 : dw ROLE_SPY
  db ET_GUARD,  34,  47, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_ngate
  db ET_GUARD,  54, 119, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_train
  db ET_GUARD, 106,  95, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_station
  db ET_GUARD,  10,  71, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_west
  db ET_GUARD, 150, 151, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_east
  db ET_GUARD, 110, 175, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_sgate
  db ET_GUARD,  58,  71, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m07_route_yard
  ; a barrel beside the middle of the train, two more on the siding
  db ET_BARREL,  74,  87, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db ET_BARREL,  18, 143, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db ET_BARREL,  22, 143, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db &FF

m07_route_ngate:                ; outside the north gate
  db 34, 47, 50
  db 58, 47, 50
  db &FF
m07_route_train:                ; along the south side of the train
  db 54, 119, 40
  db 94, 119, 40
  db &FF
m07_route_station:              ; in front of the station building
  db 106, 95, 40
  db 138, 95, 40
  db &FF
m07_route_west:                 ; where the line leaves the yard, west
  db 10, 71, 40
  db 10, 151, 40
  db &FF
m07_route_east:                 ; ... and east
  db 150, 151, 40
  db 150, 71, 40
  db &FF
m07_route_sgate:                ; outside the south gate
  db 110, 175, 50
  db 146, 175, 50
  db &FF
m07_route_yard:                 ; north of the train
  db 58, 71, 30
  db 102, 71, 30
  db &FF

M07_CAM_X       equ 0
M07_CAM_Y       equ 0
M07_GUARDS      equ 7
M07_TRAIN_COL   equ 14          ; 10x3 train stamp, top-left tile
M07_TRAIN_ROW   equ 11
M07_TRAIN_X     equ M07_TRAIN_COL*4+20      ; middle of the train (world)
M07_TRAIN_Y     equ (M07_TRAIN_ROW+3)*8-2
M07_TRUCK_X0    equ 33*4        ; truck: cols 33-35, rows 25-26; board from row 27 too
M07_TRUCK_X1    equ 36*4-1
M07_TRUCK_Y0    equ 25*8
M07_TRUCK_Y1    equ 28*8-1
