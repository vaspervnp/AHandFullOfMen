; ===========================================================================
; Video hardware: CRTC, Gate Array mode/palette, VSYNC interrupt sync
; ===========================================================================

; Standard 6128 CRTC setup with the screen at &C000 (R12/R13).
crtc_table:
  db 63, 40, 46, &8E, 38, 0, 25, 30, 0, 7, 0, 0, &30, &00
CRTC_COUNT equ $-crtc_table

video_init:
  ld bc,&7F00+GA_MODE0_NOROM
  out (c),c
  ld bc,&7F00+RAM_BASE64
  out (c),c
  ld hl,crtc_table
  xor a
.crtc:
  ld b,CRTC_SEL
  out (c),a
  ld b,CRTC_DATA
  inc b                         ; OUTI pre-decrements B
  outi
  inc a
  cp CRTC_COUNT
  jr nz,.crtc
  call palette_black
  call cls
  ret

; Blank all 16 pens and the border (used while drawing the first screen).
palette_black:
  ld bc,&7F00
  ld a,17
.lp:
  out (c),c
  ld e,&54
  out (c),e
  inc c
  dec a
  jr nz,.lp
  ret

; HL = 17 hardware colours (pens 0..15, border). Call right after a VSYNC.
palette_set:
  ld bc,&7F00
.lp:
  out (c),c
  ld a,(hl)
  out (c),a
  inc hl
  inc c
  ld a,c
  cp 17
  jr nz,.lp
  ret

cls:
  ld hl,SCREEN
  ld de,SCREEN+1
  ld bc,&3FFF
  ld (hl),0
  ldir
  ret

; ---------------------------------------------------------------------------
; Interrupts. The Gate Array fires 6 interrupts per frame (300 Hz); the one
; that lands during VSYNC is identified by PPI port B bit 0.
; ---------------------------------------------------------------------------
int_handler:
  push af
  push bc
  ld b,PPI_B
  in a,(c)
  rra
  jr nc,.done
  ld a,(vsync_count)
  inc a
  ld (vsync_count),a
.done:
  pop bc
  pop af
  ei
  ret

; Wait for the next VSYNC. Waiting time goes to background path searches
; (pf_idle halts when there is none).
wait_vsync:
  ld a,(vsync_count)
  ld (wait_v),a
.w:
  call pf_idle
  ld a,(wait_v)
  ld hl,vsync_count
  cp (hl)
  jr z,.w
  ret

; Wait until at least FRAME_STEP frames have passed since the last call
; (game runs at 25 Hz). Returns A = frames actually elapsed.
FRAME_STEP equ 2
wait_frame:
.w:
  ld hl,vsync_count
  ld a,(last_vsync)
  ld b,a
  ld a,(hl)
  sub b
  cp FRAME_STEP
  jr nc,.go
  call pf_idle
  jr .w
.go:
  ld c,a
  ld a,(hl)
  ld (last_vsync),a
  ld a,c
  ret
