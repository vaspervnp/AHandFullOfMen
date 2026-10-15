; ===========================================================================
; Mission 1: "Baptism of Fire" (Norway)
; Snow valley, frozen river, guard outpost, security gate, radio tower.
; Map source: assets/maps/mission01.txt (tile col c -> x = c*4+2,
; tile row r -> feet y = r*8+7)
; ===========================================================================

; Entity spawn records: type, x, y, dir, gfx, bank, hp, route
m01_spawns:
  ; commandos (entities 0..2)
  db ET_COMMANDO, 18, 239, DIR_N : dw spr_beret : db &C4, 8 : dw 0
  db ET_COMMANDO, 26, 247, DIR_N : dw spr_marine : db &C5, 8 : dw 0
  db ET_COMMANDO, 10, 247, DIR_N : dw spr_sniper : db &C5, 8 : dw 0
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
