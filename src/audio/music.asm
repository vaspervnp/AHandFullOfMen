; ===========================================================================
; Menu music: two voices (AY channels A and B) with a short decay, stepped
; once per 25 Hz tick from page_wait_fire. Only the title and debrief pages
; play it, so it never meets the in-game effects or the siren.
; Song data and the period table are generated into RAM bank 5 by
; tools/music2asm.py (assets/music/*.txt); see that script for the format.
; ===========================================================================

RAM_MUSIC       equ &C5         ; bank 5 at &4000 holds the songs
MUS_DECAY       equ 4           ; volume steps a note fades by
; voice state (MUS_VOICE bytes): ptr, loop start, ticks left, volume, start volume
MV_PTR          equ 0
MV_LOOP         equ 2
MV_LEFT         equ 4
MV_VOL          equ 5
MV_START        equ 6
MUS_VOICE       equ 7

; HL = song (in bank 5): start playing it
music_start:
  push hl
  call music_stop               ; (trashes HL)
  pop hl
  ld bc,&7F00+RAM_MUSIC
  out (c),c
  ld ix,mus_voices
  ld b,2
.v:
  ld e,(hl)
  inc hl
  ld d,(hl)
  inc hl
  ld (ix+MV_PTR),e
  ld (ix+MV_PTR+1),d
  ld (ix+MV_LOOP),e
  ld (ix+MV_LOOP+1),d
  ld (ix+MV_LEFT),1
  ld de,MUS_VOICE
  add ix,de
  djnz .v
  ld a,(hl)                     ; start volumes
  ld (mus_voices+MV_START),a
  inc hl
  ld a,(hl)
  ld (mus_voices+MUS_VOICE+MV_START),a
  ld bc,&7F00+RAM_BASE64
  out (c),c
  ld a,7                        ; mixer: tone on A and B only
  ld c,&3C
  call psg_write
  ld a,1
  ld (mus_on),a
  ret

; Silence everything.
music_stop:
  xor a
  ld (mus_on),a
  jp psg_init

; One tick of the current song.
music_update:
  ld a,(mus_on)
  or a
  ret z
  ld bc,&7F00+RAM_MUSIC
  out (c),c
  ld ix,mus_voices
  ld de,8*256+0                 ; D = volume register, E = tone register
  call mus_step
  ld ix,mus_voices+MUS_VOICE
  ld de,9*256+2
  call mus_step
  ld bc,&7F00+RAM_BASE64
  out (c),c
  ret

; IX = voice, D = its volume register, E = its tone register
mus_step:
  dec (ix+MV_LEFT)
  jr nz,.decay
  ld l,(ix+MV_PTR)
  ld h,(ix+MV_PTR+1)
.event:
  ld a,(hl)
  cp &FE
  jr z,.end
  cp &FF
  jr nz,.note
  ld l,(ix+MV_LOOP)             ; loop
  ld h,(ix+MV_LOOP+1)
  jr .event
.end:
  ld (ix+MV_LEFT),0             ; stays here: 256 ticks per re-check
  xor a
  jr .set_vol
.note:
  inc hl
  ld c,(hl)
  inc hl
  ld (ix+MV_LEFT),c
  ld (ix+MV_PTR),l
  ld (ix+MV_PTR+1),h
  or a
  jr z,.set_vol                 ; rest: A = 0
  dec a                         ; tone period from the table
  add a,a
  ld l,a
  ld h,0
  ld bc,music_periods
  add hl,bc
  ld c,(hl)
  ld a,e
  call psg_write
  inc hl
  ld c,(hl)
  ld a,e
  inc a
  call psg_write
  ld a,(ix+MV_START)
.set_vol:
  ld (ix+MV_VOL),a
  jr .write
.decay:                         ; fade by one step every other tick
  ld a,(ix+MV_LEFT)
  and 1
  ret nz
  ld a,(ix+MV_VOL)
  or a
  ret z
  ld c,a
  ld a,(ix+MV_START)
  sub MUS_DECAY
  cp c
  ret nc
  dec (ix+MV_VOL)
.write:
  ld c,(ix+MV_VOL)
  ld a,d
  jp psg_write
