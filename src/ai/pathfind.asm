; ===========================================================================
; Grid pathfinding (breadth-first flood fill on the tile map)
;
; path_dist is the map padded with a blocked border (42x34), so neighbour
; checks never need bounds tests. Cells hold &FE = blocked, &FF = unvisited,
; else the step distance from the goal. The flood starts at the goal and
; stops as soon as it reaches the walker, which then walks downhill,
; keeping only the turning points as waypoints. 8-way moves; a diagonal is
; only allowed when both orthogonal neighbours are open (no corner cutting),
; so straight lines between waypoints never clip a blocked tile.
;
; Per-entity path slots (entities 0..PATH_SLOTS-1):
;   +0 count  +1 next index  +2 goal x  +3 goal y  +4 repath flag
;   +5.. waypoints (x, y)
; ===========================================================================

PATH_W          equ MAP_W+2
PATH_H          equ MAP_H+2
PATH_SLOTS      equ 8
PATH_SLOT_SIZE  equ 32
PATH_MAX_WP     equ 12
PATH_QUEUE_LEN  equ 512         ; entries (16-bit cell pointers)
P_BLOCKED       equ &FE
P_OPEN          equ &FF
P_MAX_DIST      equ &FC

; IX = entity, B,C = goal (world), A = blocking tile flags.
; -> carry set if a path exists; tx/ty = first waypoint, state untouched.
path_to:
  ld (pf_mask),a
  ld a,b
  ld (pf_gx),a
  ld a,c
  ld (pf_gy),a
  call path_slot
  ret nc                        ; no slot for this entity: walk straight
  ld (pf_slot),hl
  ld a,(pf_gx)                  ; goal tile itself blocked?
  ld b,a
  ld a,(pf_gy)
  ld c,a
  call map_flags
  ld hl,pf_mask
  and (hl)
  jp nz,pf_fail
  call pf_walk_clear            ; open ground all the way: no search needed
  jp c,pf_direct
  call pf_fill
  ; goal cell
  ld a,(pf_gx)
  ld b,a
  ld a,(pf_gy)
  ld c,a
  call pf_cell
  ld a,(hl)
  cp P_BLOCKED
  jp z,pf_fail
  ld (hl),0
  ld (pf_goal),hl
  ; start cell
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  call pf_cell
  ld (pf_start),hl
  ld de,(pf_goal)
  or a
  sbc hl,de
  jp z,pf_direct                ; same tile: just walk to the point
  ld hl,(pf_start)              ; standing in a "blocked" tile (e.g. corner
  ld a,(hl)                     ; slide)? treat it as open
  cp P_BLOCKED
  jr nz,.flood
  ld (hl),P_OPEN
.flood:
  push ix                       ; the flood walks direction records in IX
  call pf_flood
  pop ix
  jp nc,pf_fail
  call pf_extract
  scf
  ret

; IX = walker. Carry if walking straight at the goal (the way ent_step
; moves: X on even ticks, Y 2 lines a tick) never enters a blocking tile.
pf_walk_clear:
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  ld e,0                        ; tick parity
.step:
  ld a,(pf_gx)
  cp b
  jr nz,.go
  ld a,(pf_gy)
  cp c
  jr nz,.go
  scf                           ; reached the goal
  ret
.go:
  bit 0,e                       ; x moves on even ticks
  jr nz,.y
  ld a,(pf_gx)
  cp b
  jr z,.y
  jr c,.left
  inc b
  jr .y
.left:
  dec b
.y:
  ld a,(pf_gy)
  sub c
  jr z,.check
  jr c,.up
  inc c
  cp 1
  jr z,.check
  inc c
  jr .check
.up:
  dec c
  cp &FF
  jr z,.check
  dec c
.check:
  inc e
  push bc
  push de
  call map_flags
  pop de
  pop bc
  ld hl,pf_mask
  and (hl)
  jr z,.step
  or a                          ; blocked
  ret

; Walk straight to the goal (same tile, or nothing in the way).
pf_direct:
  ld hl,(pf_slot)
  ld (hl),1                     ; one waypoint: the goal
  inc hl
  ld (hl),0
  inc hl
  ld a,(pf_gx)
  ld (hl),a
  inc hl
  ld a,(pf_gy)
  ld (hl),a
  inc hl
  ld (hl),0
  inc hl
  ld a,(pf_gx)
  ld (hl),a
  inc hl
  ld a,(pf_gy)
  ld (hl),a
  call path_next
  scf
  ret

pf_fail:
  ld hl,(pf_slot)
  ld (hl),0
  or a
  ret

; IX = entity -> HL = its path slot, carry set; NC if it has none
path_slot:
  ld a,(ix+ent.idx)
  cp PATH_SLOTS
  ret nc
  ld l,a
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl                     ; * 32
  ld de,path_table
  add hl,de
  scf
  ret

; IX = entity: forget its path (patrols walk straight lines)
path_clear:
  call path_slot
  ret nc
  ld (hl),0
  ret

; IX = entity that reached its current target. Loads the next waypoint into
; tx/ty -> NZ (still travelling), or Z when the path is done.
path_next:
  call path_slot
  jr nc,.done
  ld a,(hl)                     ; count
  or a
  jr z,.done
  inc hl
  ld b,(hl)                     ; next index
  cp b
  jr z,.end
  inc (hl)
  inc hl
  inc hl
  inc hl
  inc hl                        ; -> waypoints
  ld a,b
  add a,a
  add a,l
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ld a,(hl)
  ld (ix+ent.tx),a
  inc hl
  ld a,(hl)
  ld (ix+ent.ty),a
  or 1
  ret
.end:
  ; list exhausted: re-plan the rest of a long path, else done
  inc hl
  ld b,(hl)                     ; goal
  inc hl
  ld c,(hl)
  inc hl
  ld a,(hl)                     ; repath flag
  or a
  jr z,.done
  push ix
  call cmd_or_guard_mask        ; A = blocking flags for IX
  pop ix
  call path_to
  jr nc,.done
  or 1
  ret
.done:
  call path_clear
  xor a
  ret

; IX = entity -> A = tiles that block it
cmd_or_guard_mask:
  ld a,(ix+ent.type)
  cp ET_COMMANDO
  jp z,cmd_block_flags
  ld a,TF_SOLID|TF_WATER
  ret

; ---------------------------------------------------------------------------
; Flood fill internals
; ---------------------------------------------------------------------------

; Initialise path_dist from the cached walkability grid for (pf_mask):
; walkers (solid + water block) or the swimming Marine (only solid blocks).
pf_fill:
  ld a,(pf_mask)
  cp TF_SOLID
  ld hl,pf_cache_swim
  jr z,.copy
  ld hl,pf_cache_land
.copy:
  ld de,path_dist
  ld bc,PATH_W*PATH_H
  ldir
  ret

; The map changed (new mission, tower destroyed): rebuild both grids now,
; while the screen is blank or the explosion covers the pause.
path_map_changed:
  ld hl,pf_cache_land
  ld c,TF_SOLID|TF_WATER
  call pf_build_cache
  ld hl,pf_cache_swim
  ld c,TF_SOLID
  ; fall through

; HL = grid, C = blocking mask. Border and blocking tiles = &FE, else &FF.
pf_build_cache:
  ld a,c
  ld (.mask+1),a
  ld b,PATH_W                   ; top border row
  ld a,P_BLOCKED
.top:
  ld (hl),a
  inc hl
  djnz .top
  ex de,hl                      ; DE = grid
  ld hl,map_buf
  ld c,MAP_H
.row:
  ld a,P_BLOCKED                ; left border
  ld (de),a
  inc de
  ld b,MAP_W
.col:
  push hl
  ld l,(hl)                     ; tile id -> attribute (page-aligned table)
  ld h,tile_attrs>>8
  ld a,(hl)
  pop hl
.mask:
  and 0                         ; patched
  ld a,P_OPEN
  jr z,.open
  ld a,P_BLOCKED
.open:
  ld (de),a
  inc de
  inc hl
  djnz .col
  ld a,P_BLOCKED                ; right border
  ld (de),a
  inc de
  dec c
  jr nz,.row
  ex de,hl
  ld b,PATH_W                   ; bottom border row
  ld a,P_BLOCKED
.bot:
  ld (hl),a
  inc hl
  djnz .bot
  ret

; B = world x, C = world y -> HL = grid cell
pf_cell:
  ld a,c
  rrca
  rrca
  rrca
  and &1F
  inc a                         ; padded row
  ld l,a
  ld h,0
  ld d,h
  ld e,l
  add hl,hl                     ; *42 = *32 + *8 + *2
  add hl,hl
  add hl,hl
  push hl                       ; *8
  add hl,hl
  add hl,hl                     ; *32
  pop de
  add hl,de                     ; *40
  ld a,c
  rrca
  rrca
  rrca
  and &1F
  inc a
  add a,a
  ld e,a
  ld d,0
  add hl,de                     ; *42
  ld a,b
  rrca
  rrca
  and &3F
  inc a                         ; padded column
  ld e,a
  add hl,de
  ld de,path_dist
  add hl,de
  ret

; BFS from pf_goal until pf_start is labelled. Carry = reached.
; Unrolled: DE = cell being expanded, C = distance for its neighbours.
macro PF_ORTHO off
  ld hl,{off}
  add hl,de
  ld a,(hl)
  inc a                         ; P_OPEN (&FF) -> 0
  jr nz,@skip
  ld (hl),c
  call pf_visit
@skip:
mend

macro PF_DIAG off,side1,side2
  ld hl,{off}
  add hl,de
  ld a,(hl)
  inc a
  jr nz,@skip
  ld hl,{side1}                 ; no cutting past a blocked corner
  add hl,de
  ld a,(hl)
  cp P_BLOCKED
  jr z,@skip
  ld hl,{side2}
  add hl,de
  ld a,(hl)
  cp P_BLOCKED
  jr z,@skip
  ld hl,{off}
  add hl,de
  ld (hl),c
  call pf_visit
@skip:
mend

pf_flood:
  ld hl,(pf_start)              ; patch the start test in pf_visit
  ld a,l
  ld (pf_visit.lo+1),a
  ld a,h
  ld (pf_visit.hi+1),a
  ld hl,path_queue
  ld (pf_head),hl
  ld de,(pf_goal)
  ld (hl),e
  inc hl
  ld (hl),d
  inc hl
  ld (pf_tail),hl
.pop:
  ld hl,(pf_head)
  ld de,(pf_tail)
  or a
  sbc hl,de
  ret z                         ; queue empty: unreachable (NC)
  ld hl,(pf_head)
  ld e,(hl)
  inc hl
  ld d,(hl)
  inc hl
  call pf_wrap
  ld (pf_head),hl
  ld a,(de)
  inc a
  cp P_MAX_DIST
  jr nc,.pop                    ; too far: don't expand
  ld c,a
  PF_ORTHO -PATH_W
  PF_ORTHO 1
  PF_ORTHO PATH_W
  PF_ORTHO -1
  PF_DIAG -PATH_W+1, -PATH_W, 1
  PF_DIAG PATH_W+1, PATH_W, 1
  PF_DIAG PATH_W-1, PATH_W, -1
  PF_DIAG -PATH_W-1, -PATH_W, -1
  jp .pop

; HL = newly labelled cell. Reached the walker? Leave pf_flood with carry
; (drops our return address). Else enqueue it. Preserves C and DE.
pf_visit:
.lo:
  ld a,0
  cp l
  jr nz,.queue
.hi:
  ld a,0
  cp h
  jr nz,.queue
  pop hl                        ; return straight to pf_flood's caller
  scf
  ret
.queue:
  push de
  ex de,hl
  ld hl,(pf_tail)
  ld (hl),e
  inc hl
  ld (hl),d
  inc hl
  call pf_wrap
  ld (pf_tail),hl
  pop de
  ret

pf_wrap:
  ld a,h
  cp (path_queue+PATH_QUEUE_LEN*2)>>8
  ret nz
  ld hl,path_queue
  ret

; Direction records: offset(w), dcol, drow, diagonal, side1(w), side2(w)
PF_DIR_SIZE     equ 9
pf_dirs:
  dw -PATH_W   : db 0, -1, 0 : dw 0, 0                    ; N
  dw 1         : db 1, 0, 0  : dw 0, 0                    ; E
  dw PATH_W    : db 0, 1, 0  : dw 0, 0                    ; S
  dw -1        : db -1, 0, 0 : dw 0, 0                    ; W
  dw -PATH_W+1 : db 1, -1, 1 : dw -PATH_W, 1              ; NE
  dw PATH_W+1  : db 1, 1, 1  : dw PATH_W, 1               ; SE
  dw PATH_W-1  : db -1, 1, 1 : dw PATH_W, -1              ; SW
  dw -PATH_W-1 : db -1, -1, 1: dw -PATH_W, -1             ; NW

; Walk downhill from pf_start to the goal, storing turning points.
pf_extract:
  ld hl,(pf_slot)
  ld (hl),0                     ; count
  inc hl
  ld (hl),0                     ; next index
  inc hl
  ld a,(pf_gx)
  ld (hl),a
  inc hl
  ld a,(pf_gy)
  ld (hl),a
  inc hl
  ld (hl),0                     ; repath flag
  ; current tile (col, row) of the walker
  ld a,(ix+ent.x)
  rrca
  rrca
  and &3F
  ld (pf_col),a
  ld a,(ix+ent.y)
  rrca
  rrca
  rrca
  and &1F
  ld (pf_row),a
  ld hl,(pf_start)
  ld (pf_cur),hl
  ld a,&FF
  ld (pf_lastdir),a
  push ix
.step:
  ld hl,(pf_cur)
  ld a,(hl)
  or a
  jr z,.goal
  dec a
  ld (pf_d),a
  ; prefer the previous direction (fewer waypoints), then any
  ld a,(pf_lastdir)
  cp 8
  jr nc,.scan
  call pf_dir_rec
  call pf_try_down
  jr z,.take_same
.scan:
  ld ix,pf_dirs
  ld c,0
.sd:
  call pf_try_down
  jr z,.take
  ld de,PF_DIR_SIZE
  add ix,de
  inc c
  ld a,c
  cp 8
  jr nz,.sd
  jr .goal                      ; dead end (should not happen)
.take_same:
  ld a,(pf_lastdir)
  ld c,a
  jr .move
.take:
  ; direction change: the current tile is a turning point
  ld a,(pf_lastdir)
  cp &FF
  push bc
  push hl
  call nz,pf_add_wp
  pop hl
  pop bc
  ld a,c
  ld (pf_lastdir),a
.move:
  ld (pf_cur),hl
  ld a,(pf_col)
  add a,(ix+2)
  ld (pf_col),a
  ld a,(pf_row)
  add a,(ix+3)
  ld (pf_row),a
  ld hl,(pf_slot)               ; list full: stop, re-plan at its end
  ld a,(hl)
  cp PATH_MAX_WP-1
  jr c,.step
  ld de,4
  add hl,de
  ld (hl),1                     ; repath when this list runs out
  call pf_add_wp
  pop ix
  jp path_next
.goal:
  ; final waypoint: the exact goal point
  ld hl,(pf_slot)
  ld a,(hl)
  ld e,a
  inc (hl)
  ld d,0
  ld hl,(pf_slot)
  add hl,de
  add hl,de
  ld de,5
  add hl,de
  ld a,(pf_gx)
  ld (hl),a
  inc hl
  ld a,(pf_gy)
  ld (hl),a
  pop ix
  jp path_next

; IX = direction record, (pf_cur), (pf_d): Z if that neighbour is the next
; step downhill (value pf_d, corner rule respected). HL = neighbour.
pf_try_down:
  ld hl,(pf_cur)
  ld e,(ix+0)
  ld d,(ix+1)
  add hl,de
  ld a,(pf_d)
  cp (hl)
  ret nz
  ld a,(ix+4)
  or a
  ret z
  push hl
  ld hl,(pf_cur)
  ld e,(ix+5)
  ld d,(ix+6)
  add hl,de
  ld a,(hl)
  cp P_BLOCKED
  jr z,.cut
  ld hl,(pf_cur)
  ld e,(ix+7)
  ld d,(ix+8)
  add hl,de
  ld a,(hl)
  cp P_BLOCKED
  jr z,.cut
  pop hl
  xor a
  ret
.cut:
  pop hl
  or 1
  ret

; A = direction index -> IX = its record
pf_dir_rec:
  ld ix,pf_dirs
  or a
  ret z
  ld b,a
  ld de,PF_DIR_SIZE
.lp:
  add ix,de
  djnz .lp
  ret

; Append the centre of tile (pf_col, pf_row) to the waypoint list.
pf_add_wp:
  ld hl,(pf_slot)
  ld a,(hl)
  cp PATH_MAX_WP
  ret nc
  ld e,a
  inc (hl)
  ld d,0
  add hl,de
  add hl,de
  ld de,5
  add hl,de
  ld a,(pf_col)
  add a,a
  add a,a
  add a,2
  ld (hl),a
  inc hl
  ld a,(pf_row)
  add a,a
  add a,a
  add a,a
  add a,5
  ld (hl),a
  ret
