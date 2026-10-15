; ===========================================================================
; Entity table helpers and shared movement
; ===========================================================================

; A = entity index -> IX = entity (preserves all other registers + flags)
ent_ptr:
  push hl
  push af
  add a,a
  add a,ent_addr and &FF        ; table never crosses a page (asserted)
  ld l,a
  ld h,ent_addr>>8
  ld a,(hl)
  inc l
  ld h,(hl)
  ld l,a
  push hl
  pop ix
  pop af
  pop hl
  ret

  align 32                      ; 32-byte table: never crosses a page
ent_addr:
i=0
  repeat MAX_ENTS
  dw ent_table+i*ENT_SIZE
i=i+1
  rend
  assert (ent_addr and &FF00)==((ent_addr+MAX_ENTS*2-1) and &FF00)

; IX = selected commando
sel_ent:
  ld a,(sel_cmd)
  jr ent_ptr

; Find a live entity whose sprite box contains world (B, C).
; -> carry set if found, A = index, IX = entity
ent_at:
  ld ix,ent_table
  xor a
  ld (ent_scan),a
.lp:
  ld a,(ix+ent.type)
  or a
  jr z,.next
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.next
  ld a,b                        ; x in [ex-3, ex+2]
  sub (ix+ent.x)
  add a,3
  cp 6
  jr nc,.next
  ld a,(ix+ent.y)               ; y in [ey-15, ey]
  sub c
  cp 16
  jr nc,.next
  ld a,(ent_scan)
  scf
  ret
.next:
  ld de,ENT_SIZE
  add ix,de
  ld a,(ent_scan)
  inc a
  ld (ent_scan),a
  cp MAX_ENTS
  jr nz,.lp
  or a
  ret

; Step IX one movement tick toward (ent.tx, ent.ty).
; Visual speed is equal on both axes: 1 X unit (2 Mode 0 pixels) is about
; 4 scanlines, so X moves on even ticks only while Y moves 2 lines a tick.
; C = movement-blocking tile flags.
; Returns NZ while still travelling, Z when arrived or blocked.
ent_step:
  ld a,c
  ld (step_block),a
  ld a,(ix+ent.tx)
  sub (ix+ent.x)
  call carry_sign
  ld d,a                        ; sx
  ld a,(ix+ent.ty)
  sub (ix+ent.y)
  ld l,a                        ; raw dy (for the 1-line check)
  call carry_sign
  ld e,a                        ; sy
  ld a,d
  or e
  ret z                         ; arrived
  call face_signs
  ld a,(tick)
  and 1
  jr z,.x_ok
  ld d,0                        ; odd tick: no horizontal step
.x_ok:
  ld a,e
  or a
  jr z,.y_ok
  ld a,l
  cp 1
  jr z,.y_ok
  cp &FF
  jr z,.y_ok
  sla e                         ; 2 lines per tick
.y_ok:
  ld a,d
  or e
  jr nz,.move
  or 1                          ; waiting for an even tick: still travelling
  ret
.move:
  call try_move
  ret nz
  ld a,d                        ; blocked diagonally: slide along one axis
  or a
  jr z,.try_y
  ld a,e
  or a
  jr z,.blocked
  push de
  ld e,0
  call try_move
  pop de
  ret nz
.try_y:
  ld a,e
  or a
  jr z,.blocked
  ld d,0
  call try_move
  ret nz
.blocked:
  xor a
  ret

; Flags after SUB: carry -> -1, zero -> 0, else +1
carry_sign:
  jr c,.neg
  or a
  ret z
  ld a,1
  ret
.neg:
  ld a,-1
  ret

; D = sx, E = sy (each -1..1) -> ent.dir
face_signs:
  push hl
  ld a,e
  inc a                         ; (sy+1)*3 + (sx+1)
  ld l,a
  add a,a
  add a,l
  inc a
  add a,d
  ld l,a
  ld h,0
  push de
  ld de,dir_from_sign
  add hl,de
  pop de
  ld a,(hl)
  ld (ix+ent.dir),a
  pop hl
  ret

; D = dx, E = dy. Moves IX if the destination tile is not blocking.
; NZ = moved.
try_move:
  ld a,(ix+ent.x)
  add a,d
  cp MAP_W*4
  jr nc,.no
  ld b,a
  ld a,(ix+ent.y)
  add a,e
  cp 16                         ; keep the sprite inside the map
  jr c,.no
  ld c,a
  push bc
  push de
  call map_flags
  pop de
  pop bc
  ld hl,step_block
  and (hl)
  jr nz,.no
  ld (ix+ent.x),b
  ld (ix+ent.y),c
  or 1
  ret
.no:
  xor a
  ret
