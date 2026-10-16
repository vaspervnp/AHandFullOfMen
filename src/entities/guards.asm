; ===========================================================================
; Enemy sentries: waypoint patrols
; Each guard has a route: a list of (x, y, pause) triples ending in &FF,
; looping back to the start. ent.aux = byte offset of the current waypoint.
; ===========================================================================

GUARD_FIRST     equ 3           ; entity index of the first guard

guards_update:
  ld a,GUARD_FIRST
.lp:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_GUARD
  call z,guard_update
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  ret

guard_update:
  bit EF_DEAD,(ix+ent.flags)
  ret nz
  ld a,(tick)                   ; think on alternate ticks, staggered
  add a,(ix+ent.idx)
  rra
  call nc,ai_update             ; vision + state machine (src/ai/fsm.asm)
  ld a,(ix+ent.state)
  cp ST_WALK
  ret nz
  ld a,(ix+ent.timer)           ; pausing at a waypoint
  or a
  jr z,.walk
  dec (ix+ent.timer)
  ret
.walk:
  ld a,(ix+ent.ai)              ; investigating guards walk briskly
  cp AI_INVESTIGATE
  jr z,.brisk
  ld a,(tick)                   ; sentries stroll at half commando speed
  and 2
  ret nz
.brisk:
  ld c,TF_SOLID|TF_WATER
  call ent_step
  jr z,.arrived
  inc (ix+ent.anim)
  ret
.arrived:
  call path_next                ; following a route (investigating, returning)
  ret nz
  ld (ix+ent.anim),0
  ld a,(ix+ent.ai)
  cp AI_INVESTIGATE
  jr nz,.next_wp
  ld (ix+ent.state),ST_IDLE     ; at the noise: stand and look around
  ret
.next_wp:
  ; pause here, then head for the next waypoint
  call guard_route_ptr
  ld a,(ix+ent.aux)
  add a,2
  call hl_add_a
  ld a,(hl)
  ld (ix+ent.timer),a
  ld a,(ix+ent.aux)
  add a,3
  ld (ix+ent.aux),a
  ; fall through

; Load the current waypoint (wrapping at &FF) into tx/ty.
guard_load_waypoint:
  call path_clear               ; patrol legs are authored straight lines
  call guard_route_ptr
  ld a,(ix+ent.aux)
  call hl_add_a
  ld a,(hl)
  cp &FF
  jr nz,.ok
  ld (ix+ent.aux),0
  call guard_route_ptr
  ld a,(hl)
.ok:
  ld (ix+ent.tx),a
  inc hl
  ld a,(hl)
  ld (ix+ent.ty),a
  ret

; IX = guard -> HL = route start
guard_route_ptr:
  ld a,(ix+ent.idx)
  add a,a
  ld l,a
  ld h,0
  ld de,ent_route
  add hl,de
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ret

hl_add_a:
  add a,l
  ld l,a
  ret nc
  inc h
  ret
