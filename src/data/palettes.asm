; ===========================================================================
; Gate Array hardware colours (pens 0..15, then border)
; Keep in sync with tools/cpcpal.py GAME_PENS.
; ===========================================================================

pal_norway:
  db &54                        ; 0  Black
  db &4B                        ; 1  Bright White  (snow)
  db &5B                        ; 2  Pastel Cyan   (snow shade)
  db &57                        ; 3  Sky Blue
  db &44                        ; 4  Blue
  db &40                        ; 5  White/grey
  db &56                        ; 6  Green
  db &46                        ; 7  Cyan
  db &5C                        ; 8  Red
  db &4E                        ; 9  Orange
  db &47                        ; 10 Pink
  db &5E                        ; 11 Yellow/olive
  db &4C                        ; 12 Bright Red
  db &4A                        ; 13 Bright Yellow
  db &55                        ; 14 Bright Blue
  db &43                        ; 15 Pastel Yellow
  db &54                        ; border

; Pen numbers used by code
PEN_BLACK       equ 0
PEN_SNOW        equ 1
PEN_RED         equ 12
PEN_YELLOW      equ 13
PEN_HUD         equ 14
PEN_TEXT        equ 15
PEN_DKBLUE      equ 4
