; ===========================================================================
; Sound effects. One-shots play on channel C; the alarm siren is a
; continuous sweep on channel A while the base alarm is up.
; Effect format, per 25 Hz tick: tone period (word), noise period,
; mixer value, volume. Volume &FF ends the effect.
; ===========================================================================

SFX_KNIFE       equ 0
SFX_SHOT        equ 1
SFX_ALARM       equ 2
SFX_EXPLOSION   equ 3
SFX_DECOY       equ 4

MIX_C_TONE      equ &3B
MIX_C_NOISE     equ &1F
MIX_C_BOTH      equ &1B

sfx_table:
  dw sfxd_knife, sfxd_shot, sfxd_alarm_start, sfxd_explosion, sfxd_decoy

sfxd_knife:
  dw 0 : db 4,  MIX_C_NOISE, 12
  dw 0 : db 2,  MIX_C_NOISE, 8
  dw 0 : db 1,  MIX_C_NOISE, 4
  dw 0 : db 0,  0, &FF
sfxd_shot:
  dw 0 : db 10, MIX_C_NOISE, 15
  dw 0 : db 14, MIX_C_NOISE, 13
  dw 0 : db 18, MIX_C_NOISE, 10
  dw 0 : db 22, MIX_C_NOISE, 7
  dw 0 : db 26, MIX_C_NOISE, 4
  dw 0 : db 0,  0, &FF
sfxd_alarm_start:
  dw 200 : db 0, MIX_C_TONE, 13
  dw 150 : db 0, MIX_C_TONE, 13
  dw 100 : db 0, MIX_C_TONE, 13
  dw 0 : db 0,  0, &FF
sfxd_explosion:
  dw 0 : db 31, MIX_C_NOISE, 15
  dw 0 : db 31, MIX_C_NOISE, 15
  dw 0 : db 28, MIX_C_NOISE, 14
  dw 0 : db 30, MIX_C_NOISE, 13
  dw 0 : db 31, MIX_C_NOISE, 12
  dw 0 : db 31, MIX_C_NOISE, 10
  dw 0 : db 31, MIX_C_NOISE, 8
  dw 0 : db 31, MIX_C_NOISE, 6
  dw 0 : db 31, MIX_C_NOISE, 4
  dw 0 : db 31, MIX_C_NOISE, 2
  dw 0 : db 0,  0, &FF
sfxd_decoy:
  dw 60 : db 0, MIX_C_TONE, 12
  dw 50 : db 0, MIX_C_TONE, 12
  dw 60 : db 0, MIX_C_TONE, 12
  dw 50 : db 0, MIX_C_TONE, 12
  dw 0 : db 0,  0, &FF

; A = effect id
sfx_play:
  push hl
  push de
  add a,a
  ld l,a
  ld h,0
  ld de,sfx_table
  add hl,de
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ld (sfx_ptr),hl
  pop de
  pop hl
  ret

; Called once per game tick.
sfx_update:
  call siren_update
  ld hl,(sfx_ptr)
  ld a,h
  or l
  ret z
  push hl
  pop ix
  ld a,(ix+4)
  cp &FF
  jr z,.stop
  ld a,4
  ld c,(ix+0)
  call psg_write
  ld a,5
  ld c,(ix+1)
  call psg_write
  ld a,6
  ld c,(ix+2)
  call psg_write
  ld a,(ix+3)
  call mixer_c
  ld a,10
  ld c,(ix+4)
  call psg_write
  ld hl,(sfx_ptr)
  ld de,5
  add hl,de
  ld (sfx_ptr),hl
  ret
.stop:
  ld hl,0
  ld (sfx_ptr),hl
  ld a,10
  ld c,0
  jp psg_write

; A = effect mixer value; the siren keeps channel A tone enabled
mixer_c:
  ld b,a
  ld a,(alarm)
  or a
  ld a,b
  jr z,.quiet
  and &FE                       ; siren: channel A tone on
.quiet:
  ld c,a
  ld a,7
  jp psg_write

; Two-tone sweep on channel A while the alarm is active.
siren_update:
  ld a,(alarm)
  or a
  ret z
  ld a,(siren_phase)
  inc a
  ld (siren_phase),a
  and 31
  add a,a
  add a,80                      ; period 80..142: wailing up and down
  ld c,a
  ld a,(siren_phase)
  bit 5,a
  ld a,c
  jr z,.up
  neg
  add a,222
.up:
  ld c,a
  xor a
  call psg_write
  ld a,1
  ld c,0
  call psg_write
  ld a,8
  ld c,10
  call psg_write
  ld a,(sfx_ptr+1)
  or a
  ret nz                        ; effect running: it owns the mixer
  ld c,&3E                      ; only channel A tone
  ld a,7
  jp psg_write
