; ===========================================================================
; Mission 1: "Baptism of Fire" (Norway)
; Snow valley, frozen river, guard outpost, security gate, radio tower.
; Map source: assets/maps/mission01.txt (tile col c -> x = c*4+2,
; tile row r -> feet y = r*8+7)
; ===========================================================================

; Entity spawn records: type, x, y, dir, gfx, hp, route
m01_spawns:
  ; commandos (entities 0..2)
  db ET_COMMANDO, 18, 239, DIR_N : dw spr_beret : db 8 : dw 0
  db ET_COMMANDO, 26, 247, DIR_N : dw spr_beret : db 8 : dw 0
  db ET_COMMANDO, 10, 247, DIR_N : dw spr_beret : db 8 : dw 0
  ; sentries (entities 3..)
  db ET_GUARD,  98, 151, DIR_E : dw spr_guard : db 0 : dw route_bridge
  db ET_GUARD, 122, 111, DIR_S : dw spr_guard : db 0 : dw route_gate
  db ET_GUARD,  94,  63, DIR_S : dw spr_guard : db 0 : dw route_barracks
  db ET_GUARD, 138,  63, DIR_E : dw spr_guard : db 0 : dw route_tower
  db ET_GUARD,  18, 119, DIR_E : dw spr_guard : db 0 : dw route_river
  db &FF
SPAWN_SIZE equ 9

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
