; ===========================================================================
; Disk loader (runs at &9000 with the firmware still active)
;
; DISC.BAS shows the splash screen, loads this file and CALLs it. We pull
; the game in with the AMSDOS cassette-vector calls:
;   CODE.BIN    -> &0040 (base RAM)
;   SPRITES.BIN -> &4000 with RAM bank 4 paged in (&7FC4)
;   SPRITES2.BIN-> &4000 with RAM bank 5 paged in (&7FC5)
;   BANK7.BIN   -> &4000 with RAM bank 7 paged in (&7FC7): title art, maps
;   SPRITES3.BIN-> &4000 with RAM bank 6 paged in (&7FC6): Sapper, Spy
;   DATA.BIN    -> &4000 (base RAM)
; then stop the drive motor, take over the machine and jump to the game.
; ===========================================================================

TXT_OUTPUT      equ &BB5A
SCR_SET_MODE    equ &BC0E
CAS_IN_OPEN     equ &BC77
CAS_IN_CLOSE    equ &BC7A
CAS_IN_DIRECT   equ &BC83
DISK_BUFFER     equ &8800       ; 2K AMSDOS buffer, below the loader

  org &9000
loader:
  ; 128K only: on a 464/664 the &7FC4 page switch does nothing, so a byte
  ; written to "bank 4" lands in base RAM. Say so and go back to BASIC.
  ld bc,&7FC4
  out (c),c
  ld a,&55
  ld (&4000),a
  ld bc,&7FC0
  out (c),c
  ld a,&AA
  ld (&4000),a
  ld bc,&7FC4
  out (c),c
  ld a,(&4000)
  ld bc,&7FC0
  out (c),c
  cp &55
  jr z,.load
  ld a,1
  call SCR_SET_MODE
  ld hl,msg_need_128k
.msg:
  ld a,(hl)
  or a
  ret z
  call TXT_OUTPUT
  inc hl
  jr .msg
.load:
  ld hl,fn_code
  ld de,&0040
  call load_file
  ld bc,&7FC4
  out (c),c
  ld hl,fn_sprites
  ld de,&4000
  call load_file
  ld bc,&7FC5
  out (c),c
  ld hl,fn_sprites2
  ld de,&4000
  call load_file
  ld bc,&7FC7
  out (c),c
  ld hl,fn_bank7
  ld de,&4000
  call load_file
  ld bc,&7FC6
  out (c),c
  ld hl,fn_sprites3
  ld de,&4000
  call load_file
  ld bc,&7FC0
  out (c),c
  ld hl,fn_data
  ld de,&4000
  call load_file
  di
  ld bc,&FA7E                   ; drive motor off
  xor a
  out (c),a
  jp &0040

; HL = 8-byte name (+ ".BIN" -> 12 chars), DE = load address
load_file:
  push de
  ld b,12
  ld de,DISK_BUFFER
  call CAS_IN_OPEN
  pop hl
  jr nc,.fail
  call CAS_IN_DIRECT
  jr nc,.fail
  jp CAS_IN_CLOSE
.fail:
  ld bc,&7F10                   ; red border: disk error
  out (c),c
  ld a,&4C
  out (c),a
  di
  halt

msg_need_128k:
  db "A HANDFUL OF MEN needs 128K of RAM:",13,10
  db "a CPC 6128, or a 464/664 with a",13,10
  db "64K memory expansion.",13,10,0

fn_code:    db "CODE    .BIN"
fn_sprites: db "SPRITES .BIN"
fn_sprites2:db "SPRITES2.BIN"
fn_data:    db "DATA    .BIN"
fn_bank7:   db "BANK7   .BIN"
fn_sprites3:db "SPRITES3.BIN"
