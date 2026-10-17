; ===========================================================================
; Training: "Boot Camp" (mission index TUTORIAL, key 0 on the menu)
; A gentle course from the south-west corner to the truck: walk, pick a
; man, swim the river (the others take the bridge), crawl up behind a
; sentry and knife him, watch a patrol's cone, try the decoy, then let the
; Sniper shoot the barrel at the foot of the training mast. Tips in the
; HUD follow the selected commando (m08_tips). Squad: Beret, Marine, Sniper.
; Map source: assets/maps/mission08.txt (col c -> x = c*4+2, row r -> y = r*8+7)
; ===========================================================================

; descriptor first: mission_select copies it into mis
m08_desc:
  dw m08_spawns, map_mission08
  db M08_CAM_X, M08_CAM_Y
  db M08_MAST_COL, M08_MAST_ROW, 2, 4, M08_MAST_X, M08_MAST_Y
  dw m08_ruin
  db M08_TRUCK_X0, M08_TRUCK_X1, M08_TRUCK_Y0, M08_TRUCK_Y1
  dw m08_txt_name, m08_txt_brief, m08_tip_walk, m08_txt_hud2, m08_txt_obj
  db M08_GUARDS
  dw m08_briefing
  db MAP08_BANK
  dw m08_tips
m08_ruin:                       ; the mast: top half snow, base rubble
  db TILE_SNOW, TILE_SNOW, TILE_SNOW, TILE_SNOW
  db TILE_RUBBLE, TILE_SCORCH, TILE_RUBBLE, TILE_SCORCH
m08_txt_name:  db "TRAINING: BOOT CAMP",0
m08_txt_brief: db "LEARN THE ROPES, THEN THE TRUCK",0
m08_txt_hud2:  db "> GET TO THE TRUCK!  ",0
m08_txt_obj:   db "DESTROY THE TRAINING MAST ",0
m08_briefing:
  db 11, PEN_RED,  "- BOOT CAMP -",0
  db 12, PEN_TEXT, "WALK THE COURSE NORTH TO THE TRUCK",0
  db 13, PEN_TEXT, "TIPS SHOW IN THE PANEL BELOW AS",0
  db 14, PEN_TEXT, "YOUR MAN REACHES EACH LESSON",0
  db 16, PEN_RED,  "- SQUAD -",0
  db 17, PEN_TEXT, "TINY     KNIFE  D DECOY  G DRAG   ",0
  db 18, PEN_TEXT, "FINS     HARPOON  SWIMS UNSEEN    ",0
  db 19, PEN_TEXT, "DUKE     RIFLE: 5 SHOTS, LOUD     ",0
  db 21, PEN_SNOW, "SHOOT THE BARREL BY THE MAST",0
  db &FF

; HUD tips: x0, x1, y0, y1 (world, inclusive), text ("> " + 19 chars, shown in
; pink). The first
; zone holding the selected commando wins.
m08_tips:
  db 0, 47, 200, 255 : dw m08_tip_walk
  db 48, 159, 200, 255 : dw m08_tip_pick
  db 0, 159, 176, 199 : dw m08_tip_swim
  db 0, 159, 144, 175 : dw m08_tip_crawl
  db 104, 139, 112, 143 : dw m08_tip_knife
  db 0, 159, 96, 143 : dw m08_tip_cone
  db 0, 159, 72, 95 : dw m08_tip_decoy
  db 0, 159, 0, 71 : dw m08_tip_snipe
  db &FF
m08_tip_walk:  db "> ARROWS, FIRE: WALK ",0
m08_tip_pick:  db "> 1 2 3: PICK A MAN  ",0
m08_tip_swim:  db "> 2: MARINE CAN SWIM ",0
m08_tip_crawl: db "> C: CRAWL, SNEAK UP ",0
m08_tip_knife: db "> FIRE ON HIM: KNIFE ",0
m08_tip_cone:  db "> V: SEE GUARD'S CONE",0
m08_tip_decoy: db "> D: DECOY. D: PING  ",0
m08_tip_snipe: db "> 3: SNIPER SHOOTS IT",0

m08_spawns:
  db ET_COMMANDO,  6, 239, DIR_N : dw spr_beret : db RAM_SPRITES, 8 : dw ROLE_BERET
  db ET_COMMANDO, 14, 247, DIR_N : dw spr_marine : db &C5, 8 : dw ROLE_MARINE
  db ET_COMMANDO, 22, 247, DIR_N : dw spr_sniper : db &C5, 8 : dw ROLE_SNIPER
  db ET_GUARD, 122, 135, DIR_N : dw spr_guard : db RAM_SPRITES, 0 : dw m08_route_post
  db ET_GUARD,  82,  95, DIR_E : dw spr_guard : db RAM_SPRITES, 0 : dw m08_route_patrol
  ; the barrel at the foot of the mast
  db ET_BARREL, 78, 55, DIR_S : dw spr_fx : db RAM_SPRITES, 0 : dw 0
  db &FF

m08_route_post:                 ; stands north of the bridge, back to it
  db 122, 135, 250
  db &FF
m08_route_patrol:               ; paces across the middle of the camp
  db 82, 95, 50
  db 138, 95, 50
  db &FF

M08_CAM_X       equ 0
M08_CAM_Y       equ CAM_MAX_Y
M08_GUARDS      equ 2
M08_MAST_COL    equ 18          ; 2x4 mast (tower stamp), top-left tile
M08_MAST_ROW    equ 2
M08_MAST_X      equ M08_MAST_COL*4+4        ; centre of its base (world)
M08_MAST_Y      equ (M08_MAST_ROW+4)*8-2
M08_TRUCK_X0    equ 36*4        ; truck: cols 36-38, rows 1-2; board from row 3 too
M08_TRUCK_X1    equ 39*4-1
M08_TRUCK_Y0    equ 1*8
M08_TRUCK_Y1    equ 4*8-1
