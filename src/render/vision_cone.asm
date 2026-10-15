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
  call cone_erase
  jp cone_cast
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
  ld (hl),0
  inc hl
  inc de
  inc bc
  pop af
  dec a
  jr nz,.lp
  xor a
  ld (cone_count),a
  ret

; -> carry + A = index if a live guard is under the cursor
guard_under_cursor:
  call cursor_world
  call ent_at
  ret nc
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
  ld b,CONE_RAYS
.ray:
  push bc
  call cone_ray
  ld a,(cone_ang)
  add a,CONE_SPREAD
  ld (cone_ang),a
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
  ; start at the eyes, centre of the unit
  ld h,(ix+ent.x)
  ld l,128
  ld (cone_fx),hl
  ld a,(ix+ent.y)
  sub 8
  ld h,a
  ld l,128
  ld (cone_fy),hl
  ld c,0                        ; step counter
.step:
  ld a,c
  ld (cone_step),a
  ; x += dx (stop at the map edge)
  ld hl,(cone_fx)
  ld de,(cone_dx)
  add hl,de
  ld (cone_fx),hl
  ld a,h
  cp MAP_W*4
  ret nc
  ld b,a
  ; y += dy (stop on wrap past the top or bottom)
  ld hl,(cone_fy)
  ld de,(cone_dy)
  add hl,de
  push af
  bit 7,d
  jr nz,.up
  pop af
  ret c                         ; ran off the bottom
  jr .y_ok
.up:
  pop af
  ret nc                        ; ran off the top
.y_ok:
  ld (cone_fy),hl
  ld a,h
  cp 16
  ret c
  push bc
  ld c,a
  push bc
  call map_flags
  pop bc
  and TF_OPAQUE
  jr nz,.blocked
  call cone_store                ; B, C = world x, y
  pop bc
  inc c
  ld a,c
  cp CONE_STEPS
  jr nz,.step
  ret
.blocked:
  pop bc
  ret

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

; B, C = world dot; (SP+2) = step counter in its low byte. Stores the dot if
; it is inside the view.
cone_store:
  ld a,(cone_cx)
  ld e,a
  ld a,b
  sub e
  ret c
  cp SCR_W
  ret nc
  ld b,a                        ; screen x
  ld a,(cone_cy)
  ld e,a
  ld a,c
  sub e
  ret c
  cp PLAY_H
  ret nc
  ld c,a                        ; screen y
  push bc
  ld l,c                        ; offset = scr_line[y] + x
  ld h,0
  add hl,hl
  ld de,scr_line
  add hl,de
  ld e,(hl)
  inc hl
  ld d,(hl)
  ld l,b
  ld h,0
  add hl,de
  ex de,hl
  ld hl,(cone_wr)
  ld (hl),e
  inc hl
  ld (hl),d
  inc hl
  ld a,(cone_step)
  cp CONE_SHORT
  ld a,CONE_PEN_SHORT
  jr c,.zone
  ld a,CONE_PEN_LONG
.zone:
  call pen_byte
  ld (hl),a
  inc hl
  ld (cone_wr),hl
  ld hl,cone_count
  inc (hl)
  pop bc                        ; mark its tile in cone_tiles
  ld a,b
  rrca
  rrca
  and &3F
  ld b,a
  ld a,c
  rrca
  rrca
  rrca
  and &1F
  ld c,a
  ld hl,(cur_dirty)
  push hl
  ld hl,cone_tiles
  ld (cur_dirty),hl
  call mark_tile
  pop hl
  ld (cur_dirty),hl
  ret

; Plot the cached dots into the back buffer (called by render_frame).
cone_draw:
  ld a,(cone_count)
  or a
  ret z
  ld b,a
  ld a,(back_hi)
  ld c,a
  ld hl,cone_buf
.dot:
  ld e,(hl)
  inc hl
  ld a,(hl)
  inc hl
  add a,c
  ld d,a
  ld a,(hl)
  inc hl
  ld (de),a
  djnz .dot
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
