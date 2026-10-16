; ===========================================================================
; Masked software sprite blitter (Mode 0)
; Sprite data is (mask, pixels) byte pairs, row-major, and lives in extra
; RAM bank 4, paged in at &4000 with sprites_on / sprites_off.
; Mirrored (west-facing) frames are pre-generated, so there is no flip path.
; ===========================================================================

sprites_on:
  ld bc,&7F00+RAM_SPRITES       ; bank 4 -> &4000
  out (c),c
  ret

sprites_off:
  ld bc,&7F00+RAM_BASE64
  out (c),c
  ret

; Clip a sprite to the tactical area (no drawing).
; in:  HL = frame data, B = screen x byte (signed), C = screen y (signed)
;      D = width bytes, E = height lines
; out: B,C,D,E = clipped rectangle, HL = first source byte drawn,
;      A = source bytes to skip after each row; D = 0 if nothing visible
clip_rect:
  ld (bl_src),hl
  ld a,d
  ld (bl_fullw),a
  ; --- top edge
  ld a,c
  bit 7,a
  jr z,.y_pos
  neg                           ; rows hidden above the view
  cp e
  jr nc,.invis
  push bc
  ld c,a
  ld a,e
  sub c
  ld e,a
  push de
  ld a,(bl_fullw)
  add a,a
  ld e,a
  ld d,0
  ld hl,(bl_src)
.skip:
  add hl,de
  dec c
  jr nz,.skip
  ld (bl_src),hl
  pop de
  pop bc
  ld c,0
.y_pos:
  ; --- bottom edge
  ld a,c
  cp PLAY_H
  jr nc,.invis
  add a,e
  cp PLAY_H+1
  jr c,.y_ok
  ld a,PLAY_H
  sub c
  ld e,a
.y_ok:
  ; --- left edge
  ld a,b
  bit 7,a
  jr z,.x_pos
  neg                           ; columns hidden left of the view
  cp d
  jr nc,.invis
  push bc
  ld c,a
  ld a,d
  sub c
  ld d,a
  ld b,0
  ld hl,(bl_src)
  add hl,bc
  add hl,bc
  ld (bl_src),hl
  pop bc
  ld b,0
.x_pos:
  ; --- right edge
  ld a,b
  cp SCR_W
  jr nc,.invis
  add a,d
  cp SCR_W+1
  jr c,.x_ok
  ld a,SCR_W
  sub b
  ld d,a
.x_ok:
  ld a,(bl_fullw)
  sub d
  add a,a
  ld hl,(bl_src)
  ret
.invis:
  ld d,0
  ret

; HL = source, DE = screen, B = width, C = height
blit_core:
.row:
  push bc
  push de
.px:
  ld a,(de)
  and (hl)
  inc hl
  or (hl)
  inc hl
  ld (de),a
  inc de
  djnz .px
.stride:
  ld bc,0                       ; low byte patched by draw_items
  add hl,bc
  pop de
  ld a,d                        ; next scanline
  add a,8
  ld d,a
  and &38
  jr nz,.same_row
  ld a,e
  add a,SCR_W
  ld e,a
  ld a,d
  adc a,&C0                     ; -&40 to the high byte: works for both buffers
  ld d,a
.same_row:
  pop bc
  dec c
  jr nz,.row
  ret
