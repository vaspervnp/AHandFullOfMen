; ===========================================================================
; Vision cone display (Commandos-style "inspect a guard")
;
; The cone of the guard under the cursor, or the guard pinned with V, is
; drawn as CONE_RAYS dotted rays across the 60 degree arc. Each ray stops
; at the first LOS-opaque tile. Dots in the short (fatal) zone use a darker
; colour. Rays are cast into cone_buf (screen offsets + colour) only when
; the guard moves or turns or the camera scrolls. The dots are re-plotted
; every frame (cheap: they survive sprite restores that way) and their tiles
; are only marked dirty, in both buffers, when the cone changes or goes away.
; ===========================================================================

CONE_RAYS       equ 9
CONE_STEPS      equ 16          ; 5 scanlines per step = 80 (LONG_R)
CONE_SHORT      equ 6           ; steps inside the short zone (~32 lines)
CONE_SPREAD     equ 5           ; angle between rays (1/256 turns)
CONE_PEN_SHORT  equ 7           ; cyan/teal
CONE_PEN_LONG   equ 6           ; green
CONE_NONE       equ &FF
CONE_PASSES     equ 3           ; a cast is spread over 3 ticks: rays p, p+3, p+6
CONE_PASS_RAYS  equ 3
  assert CONE_PASSES*CONE_PASS_RAYS==CONE_RAYS

; Per tick: pick the guard to show and refresh its rays if needed.
cone_update:
  ld a,KEY_V
  call kbd_hit
  jr z,.pick
  ; V pins the guard under the cursor (or unpins)
  call guard_under_cursor
  jr nc,.unpin
  ld (cone_pinned),a
  jr .pick
.unpin:
  ld a,CONE_NONE
  ld (cone_pinned),a
.pick:
  ld a,(cone_pending)           ; a cast in progress: one step per tick
  or a
  jr z,.pick2
  dec a
  jr z,.show
  ld (cone_pending),a           ; next pass of the rays
  ld a,(cone_ang_b)
  add a,CONE_SPREAD
  ld (cone_ang_b),a
  ld (cone_ang),a
  ld a,(cone_key)               ; same guard as the first pass
  call ent_ptr
  ld b,CONE_PASS_RAYS
  jp cone_cast_rays
.show:                          ; complete: show it
  ld (cone_pending),a
  call cone_dirty               ; erase the old dots
  ld hl,cone_tiles_new
  ld de,cone_tiles
  ld bc,DIRTY_SIZE
  ldir
  ld a,3                        ; both buffers plot the new dots
  ld (cone_fresh),a
  ret
.pick2:
  call guard_under_cursor
  jr c,.have
  ld a,(cone_pinned)
.have:
  ld (cone_guard),a
  cp CONE_NONE
  jr z,.off
  call ent_ptr
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.dead
  ; recast when the guard, its position or facing changed
  ld hl,cone_key
  ld a,(cone_guard)
  cp (hl)
  jr nz,.cast
  inc hl
  ld a,(ix+ent.x)
  cp (hl)
  jr nz,.cast
  inc hl
  ld a,(ix+ent.y)
  cp (hl)
  jr nz,.cast
  inc hl
  ld a,(ix+ent.dir)
  cp (hl)
  jr nz,.cast
  inc hl
  ld a,(cam_x)
  cp (hl)
  jr nz,.cast
  inc hl
  ld a,(cam_y)
  cp (hl)
  ret z
.cast:
  ld hl,cone_key
  ld a,(cone_guard)
  ld (hl),a
  inc hl
  ld a,(ix+ent.x)
  ld (hl),a
  inc hl
  ld a,(ix+ent.y)
  ld (hl),a
  inc hl
  ld a,(ix+ent.dir)
  ld (hl),a
  inc hl
  ld a,(cam_x)
  ld (hl),a
  inc hl
  ld a,(cam_y)
  ld (hl),a
  call cone_cast                ; one pass now, the rest on the next
  ld a,CONE_PASSES              ; ticks, then shown: casting and erasing
  ld (cone_pending),a           ; the old cone never share a tick
  ret
.dead:
  ld a,CONE_NONE
  ld (cone_pinned),a
  ld (cone_guard),a
.off:
  ld a,(cone_count)
  or a
  call nz,cone_erase
  xor a
  ld (cone_count),a
  ld a,CONE_NONE
  ld (cone_key),a
  ret

; Schedule the old cone's tiles for redraw in both buffers, forget them.
cone_erase:
  call cone_dirty
  ld hl,cone_tiles
  ld b,DIRTY_SIZE
  xor a
.lp:
  ld (hl),a
  inc hl
  djnz .lp
  ld (cone_count),a
  ret

; Mark the cone's tiles dirty in both buffers.
cone_dirty:
  ld hl,cone_tiles
  ld de,dirty_c0
  ld bc,dirty_80
  ld a,DIRTY_SIZE
.lp:
  push af
  ld a,(de)
  or (hl)
  ld (de),a
  ld a,(bc)
  or (hl)
  ld (bc),a
  inc hl
  inc de
  inc bc
  pop af
  dec a
  jr nz,.lp
  ret

; -> carry + A = index if a live guard is under the cursor
; (update_cursor_frame found the entity there this tick)
guard_under_cursor:
  ld a,(cursor_ent)
  cp MAX_ENTS
  ret nc
  call ent_ptr
  ld b,a
  ld a,(ix+ent.type)
  cp ET_GUARD
  ld a,b
  scf
  ret z
  or a
  ret

; IX = guard. Fill cone_buf with (screen offset, colour) dots and
; cone_tiles with the view tiles they touch.
cone_cast:
  ld hl,cone_tiles_new
  ld b,DIRTY_SIZE
  xor a
.clr:
  ld (hl),a
  inc hl
  djnz .clr
  ld a,CONE_PEN_SHORT
  call pen_byte
  ld (cone_pen_s),a
  ld a,CONE_PEN_LONG
  call pen_byte
  ld (cone_pen_l),a
  xor a
  ld (cone_count),a
  ld hl,cone_buf
  ld (cone_wr),hl
  ld a,(cam_x)
  add a,a
  add a,a
  ld (cone_cx),a
  ld a,(cam_y)
  add a,a
  add a,a
  add a,a
  ld (cone_cy),a
  ld a,(ix+ent.dir)
  rrca                          ; dir * 32
  rrca
  rrca
  sub CONE_SPREAD*(CONE_RAYS-1)/2
  ld (cone_ang),a
  ld (cone_ang_b),a             ; first ray of the next pass
  ld b,CONE_PASS_RAYS
; Cast B more rays from (cone_ang), appending to cone_buf.
cone_cast_rays:
.ray:
  push bc
  call cone_ray
  ld a,(cone_ang)
  add a,CONE_SPREAD*CONE_PASSES ; interleaved: the passes share the
  ld (cone_ang),a               ; work evenly
  pop bc
  djnz .ray
  ret

; One ray at angle (cone_ang) from IX's eyes.
cone_ray:
  ; x step (8.8 world units) = sin * 2.5: a step is 5 lines and one X unit
  ; is about 4 lines wide
  ld a,(cone_ang)
  call sin_a
  ld l,a
  rla
  sbc a,a
  ld h,a
  ld d,h
  ld e,l
  add hl,hl
  add hl,hl
  add hl,de                     ; *5
  sra h
  rr l                          ; /2
  ld (cone_dx),hl
  ; y step = -cos * 10 (5 lines per step, cos table is *127)
  ld a,(cone_ang)
  add a,64
  call sin_a
  neg
  ld l,a
  rla
  sbc a,a
  ld h,a
  ld d,h
  ld e,l
  add hl,hl                     ; *2
  add hl,hl                     ; *4
  add hl,de                     ; *5
  add hl,hl                     ; *10
  ld (cone_dy),hl
  ; sides of the view this ray moves away from (cone_store's codes)
  ld c,0
  ld hl,(cone_dx)
  ld a,h
  or l
  jr z,.dy
  ld c,1                        ; left
  bit 7,h
  jr nz,.dy
  ld c,2                        ; right
.dy:
  ld hl,(cone_dy)
  ld a,h
  or l
  jr z,.away
  ld a,4                        ; up
  bit 7,h
  jr nz,.up
  ld a,8                        ; down
.up:
  or c
  ld c,a
.away:
  ld a,c
  ld (cone_away),a
  ; IY = x, BC = dx; alternate set: HL = y, BC = dy, D = step (all 8.8)
  push iy
  ld bc,(cone_dx)
  ld a,(ix+ent.x)               ; start at the eyes, centre of the unit
  ld iyh,a
  ld iyl,128
  ld a,(ix+ent.y)
  sub 8
  exx
  ld h,a
  ld l,128
  ld bc,(cone_dy)
  ld d,0
  exx
.step:
  add iy,bc                     ; x += dx (stop at the map edge)
  ld a,iyh
  cp MAP_W*4
  jr nc,.end
  ld e,a
  exx
  add hl,bc                     ; y += dy
  ld a,d
  ld (cone_step),a
  inc d
  ld a,h
  exx
  cp 16                         ; off the top, or wrapped past the bottom
  jr c,.end
  ld d,a
  rrca                          ; map row address
  rrca
  rrca
  and &1F
  add a,a
  add a,map_rows and &FF
  ld l,a
  ld h,map_rows>>8
  ld a,(hl)
  inc l
  ld h,(hl)
  ld l,a
  ld a,e
  rrca
  rrca
  and &3F
  add a,l
  ld l,a
  adc a,h
  sub l
  ld h,a
  ld a,(hl)                     ; tile -> attributes
  ld l,a
  ld h,tile_attrs>>8
  ld a,(hl)
  and TF_OPAQUE
  jr nz,.end
  push bc
  push de
  ld b,e
  ld c,d
  call cone_store
  pop de
  pop bc
  jr nc,.next
  ld hl,cone_away               ; outside, heading away from the view: done
  and (hl)
  jr nz,.end
.next:
  exx
  ld a,d
  exx
  cp CONE_STEPS
  jr nz,.step
.end:
  pop iy
  ret

; Rows of map_buf (cone_ray)
  align 64
map_rows:
  repeat MAP_H,row
  dw map_buf+(row-1)*MAP_W
  rend

; A = angle -> A = sin * 127 (signed)
sin_a:
  push hl
  ld l,a
  ld h,0
  push de
  ld de,sin_tab
  add hl,de
  pop de
  ld a,(hl)
  pop hl
  ret

; B, C = world dot, (cone_step) = step. Stores the dot if it is inside the
; view, else returns carry and A = the side it is off: 1 left, 2 right,
; 4 above, 8 below.
cone_store:
  ld a,(cone_cx)
  ld e,a
  ld a,b
  sub e
  jr c,.left
  cp SCR_W
  jr nc,.right
  ld b,a                        ; screen x
  ld a,(cone_cy)
  ld e,a
  ld a,c
  sub e
  jr c,.above
  cp PLAY_H
  jr nc,.below
  ld c,a                        ; screen y
  ld l,c                        ; offset = scr_line[y] + x
  ld h,0
  add hl,hl
  ld de,scr_line
  add hl,de
  ld a,(hl)
  inc hl
  ld h,(hl)
  add a,b
  ld l,a
  jr nc,.nc
  inc h
.nc:
  ex de,hl
  ld hl,(cone_wr)
  ld (hl),e
  inc hl
  ld (hl),d
  inc hl
  ld a,c                        ; dirty map byte: row * 3 + column / 8
  rrca
  rrca
  rrca
  and &1F
  ld e,a
  add a,a
  add a,e
  ld e,a
  ld a,b
  rlca
  rlca
  rlca
  and 3
  add a,e
  ld (hl),a
  inc hl
  ld e,a
  ld a,b                        ; ... and bit: column and 7
  rrca
  rrca
  and 7
  or bit_tab and &FF
  ld c,a
  ld b,bit_tab>>8
  ld a,(bc)
  ld (hl),a
  inc hl
  ld c,a                        ; mark the tile in cone_tiles_new
  ld a,e
  add a,cone_tiles_new and &FF
  ld e,a
  ld d,cone_tiles_new>>8
  ld a,(de)
  or c
  ld (de),a
  ld a,(cone_step)
  cp CONE_SHORT
  ld a,(cone_pen_s)
  jr c,.zone
  ld a,(cone_pen_l)
.zone:
  ld (hl),a
  inc hl
  ld (cone_wr),hl
  ld hl,cone_count
  inc (hl)
  or a
  ret
.left:
  ld a,1
  scf
  ret
.right:
  ld a,2
  scf
  ret
.above:
  ld a,4
  scf
  ret
.below:
  ld a,8
  scf
  ret

; Plot the cached dots: all of them right after a recast (cone_plot_all),
; else those on tiles restored this frame (elsewhere the dot from an
; earlier frame is still there, possibly under a sprite).
CONE_DOT        equ 5           ; screen offset (2), dirty byte, bit, pen
cone_draw:
  ld a,(cone_count)
  or a
  ret z
  ld b,a
  ld a,(cone_plot_all)
  or a
  jr z,.filtered
  ld a,(back_hi)
  ld c,a
  ld hl,cone_buf
.all:
  ld e,(hl)
  inc hl
  ld a,(hl)
  add a,c
  ld d,a
  inc hl
  inc hl
  inc hl
  ld a,(hl)
  ld (de),a
  inc hl
  djnz .all
  ret
.filtered:
  ld a,b
  push ix
  ld ixl,a
  ld a,(back_hi)
  ld (.hi+1),a
  ld a,(cur_dirty)
  ld (.base+1),a
  ld a,(cur_dirty+1)
  ld b,a
  ld hl,cone_buf
.dot:
  ld e,(hl)
  inc hl
  ld a,(hl)
  inc hl
.hi:
  add a,0
  ld d,a
  ld a,(hl)
  inc hl
.base:
  add a,0                       ; dirty map: aligned, never crosses a page
  ld c,a
  ld a,(bc)
  and (hl)
  inc hl
  jr z,.skip
  ld a,(hl)
  ld (de),a
.skip:
  inc hl
  dec ixl
  jr nz,.dot
  pop ix
  ret

; sin(a * 2pi / 256) * 127
sin_tab:
  db 0,3,6,9,12,16,19,22,25,28,31,34,37,40,43,46
  db 49,51,54,57,60,63,65,68,71,73,76,78,81,83,85,88
  db 90,92,94,96,98,100,102,104,106,107,109,111,112,113,115,116
  db 117,118,120,121,122,122,123,124,125,125,126,126,126,127,127,127
  db 127,127,127,127,126,126,126,125,125,124,123,122,122,121,120,118
  db 117,116,115,113,112,111,109,107,106,104,102,100,98,96,94,92
  db 90,88,85,83,81,78,76,73,71,68,65,63,60,57,54,51
  db 49,46,43,40,37,34,31,28,25,22,19,16,12,9,6,3
  db 0,-3,-6,-9,-12,-16,-19,-22,-25,-28,-31,-34,-37,-40,-43,-46
  db -49,-51,-54,-57,-60,-63,-65,-68,-71,-73,-76,-78,-81,-83,-85,-88
  db -90,-92,-94,-96,-98,-100,-102,-104,-106,-107,-109,-111,-112,-113,-115,-116
  db -117,-118,-120,-121,-122,-122,-123,-124,-125,-125,-126,-126,-126,-127,-127,-127
  db -127,-127,-127,-127,-126,-126,-126,-125,-125,-124,-123,-122,-122,-121,-120,-118
  db -117,-116,-115,-113,-112,-111,-109,-107,-106,-104,-102,-100,-98,-96,-94,-92
  db -90,-88,-85,-83,-81,-78,-76,-73,-71,-68,-65,-63,-60,-57,-54,-51
  db -49,-46,-43,-40,-37,-34,-31,-28,-25,-22,-19,-16,-12,-9,-6,-3
