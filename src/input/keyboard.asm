; ===========================================================================
; Keyboard matrix scanner (PSG port A via PPI)
; keymap holds 10 lines, bit = 0 when the key is down. Key codes in defs.asm
; are &LB (line, bit).
; ===========================================================================

kbd_scan:
  ld hl,keymap
  ld de,keymap_prev
  ld bc,10
  ldir                          ; remember last frame for edge detection
  di
  ld bc,&F40E                   ; PSG register 14 = port A
  out (c),c
  ld bc,&F6C0                   ; PSG: select register
  out (c),c
  xor a
  out (c),a                     ; PSG: inactive
  ld bc,&F792                   ; PPI port A = input
  out (c),c
  ld hl,keymap
  ld a,&40                      ; PSG read + line 0
  ld e,10
.line:
  ld b,PPI_C
  out (c),a
  ld b,PPI_A
  ini                           ; (HL) <- port, HL++ (B decremented after the read)
  inc a
  dec e
  jr nz,.line
  ld bc,&F782                   ; PPI port A = output again
  out (c),c
  ld bc,&F600
  out (c),c
  ei
  ; summary flags so idle frames skip the per-key tests
  ld hl,keymap
  ld de,keymap_prev
  ld bc,10*256+0
.new:
  ld a,(de)                     ; prev up (1) and now down (0)
  cpl
  or (hl)
  cpl
  or c
  ld c,a
  inc hl
  inc de
  djnz .new
  ld a,c
  ld (kbd_new),a                ; nonzero: some key went down
  ld hl,keymap
  ld b,10
  ld a,&FF
.any:
  and (hl)
  inc hl
  djnz .any
  cpl
  ld (kbd_any),a                ; nonzero: some key is held
  ret

; A = key code. Returns NZ if the key is held.
kbd_down:
  ld hl,keymap
  jr kbd_test

; A = key code. Returns NZ only on the frame the key goes down.
kbd_hit:
  ld c,a
  ld a,(kbd_new)
  or a
  ret z                         ; nothing went down this frame
  ld a,c
  push af
  ld hl,keymap_prev
  call kbd_test
  jr nz,.was_down
  pop af
  jr kbd_down
.was_down:
  pop af
  xor a                         ; Z: already held last frame
  ret

; HL = matrix, A = key code -> NZ if pressed. Trashes BC, HL.
kbd_test:
  ld c,a
  rrca
  rrca
  rrca
  rrca
  and &0F
  add a,l
  ld l,a
  adc a,h
  sub l
  ld h,a
  ld a,c
  and 7
  add a,bit_tab and &FF
  ld c,a
  ld b,bit_tab>>8
  ld a,(bc)
  ld c,a
  ld a,(hl)
  cpl
  and c
  ret
