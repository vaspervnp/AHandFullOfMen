; ===========================================================================
; Joystick + direction keys -> one direction/fire byte per frame
; Joystick 0 shares matrix line 9. Cursor keys and QAOP mirror it.
; ===========================================================================

JOY_UP          equ 0           ; bit numbers in joy_state
JOY_DOWN        equ 1
JOY_LEFT        equ 2
JOY_RIGHT       equ 3
JOY_FIRE        equ 4
JOY_FIRE2       equ 5

joy_read:
  ld a,(joy_state)
  ld (joy_prev),a
  ld a,(keymap+9)
  cpl
  and &3F                       ; bits 0..5 map 1:1 to the JOY_* layout above
  ld e,a
  ld a,(keymap+9)               ; joystick fire buttons are bits 4 (fire2), 5 (fire1)
  cpl
  ld d,0
  bit 5,a
  jr z,.nf1
  set JOY_FIRE,d
.nf1:
  bit 4,a
  jr z,.nf2
  set JOY_FIRE2,d
.nf2:
  ld a,e
  and &0F
  or d
  ld e,a
  ld hl,joy_keys
  ld b,JOY_KEY_COUNT
.k:
  push bc
  push hl
  push de
  ld a,(hl)
  call kbd_down
  pop de
  pop hl
  pop bc
  inc hl
  jr z,.next
  ld a,(hl)
  or e
  ld e,a
.next:
  inc hl
  djnz .k
  ld a,e
  ld (joy_state),a
  ret

joy_keys:
  db KEY_UP,    1<<JOY_UP
  db KEY_DOWN,  1<<JOY_DOWN
  db KEY_LEFT,  1<<JOY_LEFT
  db KEY_RIGHT, 1<<JOY_RIGHT
  db KEY_Q,     1<<JOY_UP
  db KEY_A,     1<<JOY_DOWN
  db KEY_O,     1<<JOY_LEFT
  db KEY_P,     1<<JOY_RIGHT
  db KEY_SPACE, 1<<JOY_FIRE
  db KEY_COPY,  1<<JOY_FIRE
  db KEY_RETURN,1<<JOY_FIRE2
JOY_KEY_COUNT equ ($-joy_keys)/2

; Returns NZ if fire went down this frame.
joy_fire_hit:
  ld a,(joy_prev)
  cpl
  ld b,a
  ld a,(joy_state)
  and b
  and 1<<JOY_FIRE
  ret

joy_fire2_hit:
  ld a,(joy_prev)
  cpl
  ld b,a
  ld a,(joy_state)
  and b
  and 1<<JOY_FIRE2
  ret
