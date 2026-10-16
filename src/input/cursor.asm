; ===========================================================================
; Crosshair cursor: screen-space position, accelerates while held, scrolls
; the camera when pushed against the edge of the tactical area.
; ===========================================================================

CUR_MAX_X       equ SCR_W-1
CUR_MAX_Y       equ PLAY_H-1
SCROLL_STEP     equ 2           ; tiles per edge scroll

cursor_update:
  ld a,(joy_state)
  and &0F
  jr nz,.held
  xor a
  ld (cur_hold),a
  ret
.held:
  ld a,(cur_hold)
  cp 255
  jr z,.fast
  inc a
  ld (cur_hold),a
.fast:
  ld b,1                        ; dx bytes
  ld c,3                        ; dy lines
  cp 6
  jr c,.slow
  ld b,2
  ld c,6
.slow:
  ld a,(joy_state)
  bit JOY_LEFT,a
  call nz,cur_left
  ld a,(joy_state)
  bit JOY_RIGHT,a
  call nz,cur_right
  ld a,(joy_state)
  bit JOY_UP,a
  call nz,cur_up
  ld a,(joy_state)
  bit JOY_DOWN,a
  call nz,cur_down
  ret

cur_left:
  ld a,(cursor_x)
  sub b
  jr nc,.ok
  xor a
  ld (cursor_x),a
  ld a,(redraw_row)             ; finish drawing the last scroll first
  or a
  ret nz
  ld a,(cam_x)
  or a
  ret z
  sub SCROLL_STEP
  jr nc,.cam
  xor a
.cam:
  ld (cam_x),a
  jp view_scrolled
.ok:
  ld (cursor_x),a
  ret

cur_right:
  ld a,(cursor_x)
  add a,b
  cp CUR_MAX_X+1
  jr c,.ok
  ld a,CUR_MAX_X
  ld (cursor_x),a
  ld a,(redraw_row)             ; finish drawing the last scroll first
  or a
  ret nz
  ld a,(cam_x)
  cp CAM_MAX_X
  ret z
  add a,SCROLL_STEP
  cp CAM_MAX_X+1
  jr c,.cam
  ld a,CAM_MAX_X
.cam:
  ld (cam_x),a
  jp view_scrolled
.ok:
  ld (cursor_x),a
  ret

cur_up:
  ld a,(cursor_y)
  sub c
  jr nc,.ok
  xor a
  ld (cursor_y),a
  ld a,(redraw_row)             ; finish drawing the last scroll first
  or a
  ret nz
  ld a,(cam_y)
  or a
  ret z
  sub SCROLL_STEP
  jr nc,.cam
  xor a
.cam:
  ld (cam_y),a
  jp view_scrolled
.ok:
  ld (cursor_y),a
  ret

cur_down:
  ld a,(cursor_y)
  add a,c
  cp CUR_MAX_Y+1
  jr c,.ok
  ld a,CUR_MAX_Y
  ld (cursor_y),a
  ld a,(redraw_row)             ; finish drawing the last scroll first
  or a
  ret nz
  ld a,(cam_y)
  cp CAM_MAX_Y
  ret z
  add a,SCROLL_STEP
  cp CAM_MAX_Y+1
  jr c,.cam
  ld a,CAM_MAX_Y
.cam:
  ld (cam_y),a
  jp view_scrolled
.ok:
  ld (cursor_y),a
  ret

; Both buffers need a full tactical-area redraw.
view_scrolled:
  ld a,3
  ld (view_dirty),a
  ret

; -> B = cursor world x, C = cursor world y
cursor_world:
  ld a,(cam_x)
  add a,a
  add a,a
  ld b,a
  ld a,(cursor_x)
  add a,b
  ld b,a
  ld a,(cam_y)
  add a,a
  add a,a
  add a,a
  ld c,a
  ld a,(cursor_y)
  add a,c
  ld c,a
  ret
