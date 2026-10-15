; ===========================================================================
; Vision geometry: visual-space vector, distance, angle, line of sight
;
; World X units are 4 scanlines wide on screen, so vectors are converted to
; "visual" units (vx = dx*4, vy = dy) before measuring distance and angle.
; Angles are 0..255 clockwise from north (64 = east), matching dir*32.
; ===========================================================================

VIS_MAX         equ 127         ; clamp for visual components

; IX = observer, IY = target -> vis_vx, vis_vy (signed visual units)
; Returns carry set if the target is out of range (any |component| > 127).
vis_vector:
  ld a,(iy+ent.x)
  sub (ix+ent.x)
  jr c,.xneg
  cp 32
  jr nc,.far
  add a,a
  add a,a
  jr .xset
.xneg:
  neg
  cp 32
  jr nc,.far
  add a,a
  add a,a
  neg
.xset:
  ld (vis_vx),a
  ld a,(iy+ent.y)
  sub (ix+ent.y)
  jr c,.yneg
  cp VIS_MAX+1
  jr nc,.far
  jr .yset
.yneg:
  neg
  cp VIS_MAX+1
  jr nc,.far
  neg
.yset:
  ld (vis_vy),a
  or a
  ret
.far:
  scf
  ret

; vis_vx/vis_vy -> vis_ax/vis_ay (absolute), A = approximate distance
; (max + min/2, overestimates by at most ~12%)
vis_distance:
  ld a,(vis_vx)
  call abs_a
  ld (vis_ax),a
  ld b,a
  ld a,(vis_vy)
  call abs_a
  ld (vis_ay),a
  ld c,a
  cp b
  jr nc,.cmax                   ; C >= B
  ld a,c
  ld c,b
  ld b,a                        ; B = min, C = max
.cmax:
  srl b
  ld a,c
  add a,b
  ret nc
  ld a,255
  ret

abs_a:
  bit 7,a
  ret z
  neg
  ret

; After vis_distance: A = angle of (vis_vx, vis_vy) clockwise from north.
vis_angle:
  ld a,(vis_ax)
  ld b,a
  ld a,(vis_ay)
  ld c,a
  or b
  ret z                         ; on top of each other
  ld a,b
  cp c
  jr c,.steep
  ; ax >= ay: alpha = atan(ay/ax)
  ld a,c
  ld e,b
  call ratio32
  call atan_lookup
  jr .quadrant
.steep:
  ; ax < ay: alpha = 64 - atan(ax/ay)
  ld a,b
  ld e,c
  call ratio32
  call atan_lookup
  neg
  add a,64
.quadrant:
  ld c,a                        ; alpha: angle up from the x axis (0..64)
  ld a,(vis_vx)
  bit 7,a
  jr nz,.west
  ld a,(vis_vy)
  bit 7,a
  jr z,.se
  ld a,64                       ; NE (or due north/east): 64 - alpha
  sub c
  ret
.se:
  ld a,(vis_vy)
  or a
  jr z,.ne_axis
  ld a,64
  add a,c
  ret
.ne_axis:
  ld a,64
  sub c
  ret
.west:
  ld a,(vis_vy)
  bit 7,a
  jr nz,.nw
  or a
  jr z,.nw
  ld a,192                      ; SW: 192 - alpha
  sub c
  ret
.nw:
  ld a,192
  add a,c
  ret

; A = numerator (<= E), E = denominator (> 0) -> A = A*32/E (0..32)
ratio32:
  ld l,a
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl                     ; HL = num * 32
  ld d,0
  xor a
  ld b,a                        ; quotient in B
.div:
  or a
  sbc hl,de
  jr c,.done
  inc b
  jr .div
.done:
  ld a,b
  ret

atan_lookup:
  ld l,a
  ld h,0
  ld de,atan_tab
  add hl,de
  ld a,(hl)
  ret

; atan(r/32) in 1/256ths of a turn, r = 0..32
atan_tab:
  db 0,1,3,4,5,6,8,9,10,11,12,13,15,16,17,18,19,20,21,22,23,24,25,25,26,27,28,29,29,30,31,31,32

; ---------------------------------------------------------------------------
; Line of sight from IX's eyes to IY's body. 16 samples along the segment
; are tested against TF_OPAQUE tiles. Carry set = blocked.
; ---------------------------------------------------------------------------
LOS_SAMPLES     equ 16

los_clear:
  ; start point in 12.4 fixed point
  ld a,(ix+ent.x)
  call .fx
  ld (los_x),hl
  ld a,(ix+ent.y)
  sub 10                        ; eye height
  call .fx
  ld (los_y),hl
  ; per-sample step = delta (since delta*16/16 samples)
  ld a,(iy+ent.x)
  sub (ix+ent.x)
  call .sext
  ld (los_dx),hl
  ld a,(iy+ent.y)
  sub 6                         ; aim at the chest
  ld b,a
  ld a,(ix+ent.y)
  sub 10
  ld c,a
  ld a,b
  sub c
  call .sext
  ld (los_dy),hl
  ld b,LOS_SAMPLES-1
.step:
  push bc
  ld hl,(los_x)
  ld de,(los_dx)
  add hl,de
  ld (los_x),hl
  call .int
  ld b,a
  ld hl,(los_y)
  ld de,(los_dy)
  add hl,de
  ld (los_y),hl
  call .int
  ld c,a
  call map_flags
  pop bc
  and TF_OPAQUE
  scf
  ret nz
  djnz .step
  or a
  ret

.fx:                            ; A (unsigned) -> HL = A*16
  ld l,a
  ld h,0
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ret
.sext:                          ; A (signed) -> HL sign-extended
  ld l,a
  rla
  sbc a,a
  ld h,a
  ret
.int:                           ; HL (12.4) -> A = integer part
  srl h
  rr l
  srl h
  rr l
  srl h
  rr l
  srl h
  rr l
  ld a,l
  ret
