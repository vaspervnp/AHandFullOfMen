; ===========================================================================
; AY-3-8912 register access through the PPI
; ===========================================================================

; A = register, C = value
psg_write:
  ld b,PPI_A
  out (c),a                     ; register number on the bus
  ld b,PPI_C
  ld a,&C0                      ; select register
  out (c),a
  xor a                         ; inactive
  out (c),a
  ld b,PPI_A
  out (c),c                     ; value on the bus (port decode ignores C)
  ld b,PPI_C
  ld a,&80                      ; write data
  out (c),a
  xor a
  out (c),a
  ret

psg_init:
  ld hl,psg_silence
  xor a
.lp:
  ld c,(hl)
  push af
  push hl
  call psg_write
  pop hl
  pop af
  inc hl
  inc a
  cp 14
  jr nz,.lp
  ret

psg_silence:
  db 0,0, 0,0, 0,0, 0, &3F, 0,0,0, 0,0, 0
