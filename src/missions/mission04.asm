; ===========================================================================
; Mission 4: "A Bridge Too Far" (Norway, a river line)
; A railway runs north over a steel bridge, sandbagged posts at both ends,
; an ice crossing in the west, a camp and the escape truck on the far
; (north) bank. Squad: Green Beret, Sapper, Sniper.
; Map source: assets/maps/mission04.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

m04_spawns:
  db ET_COMMANDO, 10, 247, DIR_N : dw spr_beret : db RAM_SPRITES, 8 : dw ROLE_BERET
  db ET_COMMANDO, 18, 247, DIR_N : dw spr_sapper : db RAM_BANK6, 8 : dw ROLE_SAPPER
  db ET_COMMANDO,  6, 247, DIR_N : dw spr_sniper : db &C5, 8 : dw ROLE_SNIPER
  db ET_GUARD,  70, 167, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_south
  db ET_GUARD, 106, 119, DIR_W : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_north
  db ET_GUARD,  14, 111, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_ice
  db ET_GUARD,  30,  31, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_camp
  db ET_GUARD, 110,  55, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_truck
  db ET_GUARD,  50, 199, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_woods
  db ET_GUARD,  86,  23, DIR_S : dw spr_guard : db RAM_SPRITES, 0 : dw m04_route_rail
  ; a fuel barrel by the store hut
  db ET_BARREL, 122, 95, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db &FF

m04_route_south:                ; south end of the bridge
  db 70, 167, 40
  db 106, 167, 40
  db &FF
m04_route_north:                ; north end of the bridge
  db 106, 119, 50
  db 70, 119, 50
  db &FF
m04_route_ice:                  ; watches the ice crossing
  db 14, 111, 40
  db 42, 111, 40
  db &FF
m04_route_camp:                 ; round the barracks
  db 30, 31, 20
  db 58, 31, 20
  db 58, 71, 20
  db 30, 71, 20
  db &FF
m04_route_truck:
  db 110, 55, 50
  db 138, 55, 50
  db &FF
m04_route_woods:                ; the south bank woods
  db 50, 199, 30
  db 78, 199, 30
  db &FF
m04_route_rail:                 ; walks the line north of the river
  db 86, 23, 30
  db 86, 95, 30
  db &FF

M04_CAM_X       equ 0
M04_CAM_Y       equ CAM_MAX_Y
M04_GUARDS      equ 7
M04_BRIDGE_COL  equ 20          ; 4x3 rail bridge stamp, top-left tile
M04_BRIDGE_ROW  equ 16
M04_BRIDGE_X    equ M04_BRIDGE_COL*4+8      ; middle of the span (world)
M04_BRIDGE_Y    equ (M04_BRIDGE_ROW+1)*8+4
M04_TRUCK_X0    equ 36*4        ; truck: cols 36-38, rows 1-2; board from row 3 too
M04_TRUCK_X1    equ 39*4-1
M04_TRUCK_Y0    equ 1*8
M04_TRUCK_Y1    equ 4*8-1
