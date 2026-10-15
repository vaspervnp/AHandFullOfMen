; ===========================================================================
; Guard AI: Patrol -> Investigate -> Suspicious -> Alarm
;
; Vision cone: 60 degree arc (+-21 angle units) around the facing direction.
;   short zone (<= SHORT_R): sees standing and crawling commandos, corpses
;   long zone  (<= LONG_R):  sees standing commandos only
; Distances are in visual units (scanlines).
; ===========================================================================

SHORT_R         equ 32
LONG_R          equ 80
CONE_HALF       equ 21          ; 30 degrees in 1/256 turns
SUSPECT_TICKS   equ 19          ; 1.5 s (AI runs at 12.5 Hz per guard)
CALM_TICKS      equ 25          ; how long a suspicious guard stays wary
FIRE_TICKS      equ 6           ; shot interval in combat (~1 s)
SHOT_DAMAGE     equ 3

; IX = guard
ai_update:
  ld a,(ix+ent.ai)
  cp AI_SUSPICIOUS
  jr z,ai_do_suspicious
  cp AI_ALARM
  jp z,ai_do_alarm
  cp AI_INVESTIGATE
  jr z,ai_do_investigate
  ; --- AI_PATROL
  call guard_look
  ret nc
  ; spotted something
  ld (ix+ent.ai_seen),a
  cp CMD_COUNT
  jr nc,.corpse                 ; a dead comrade: raise the alarm at once
  ld (ix+ent.ai),AI_SUSPICIOUS
  ld (ix+ent.ai_timer),SUSPECT_TICKS
  ld (ix+ent.state),ST_IDLE
  ret
.corpse:
  jp raise_alarm

ai_do_investigate:
  call guard_look
  jr nc,.look
  ld (ix+ent.ai_seen),a
  ld (ix+ent.ai),AI_SUSPICIOUS
  ld (ix+ent.ai_timer),SUSPECT_TICKS
  ld (ix+ent.state),ST_IDLE
  ret
.look:
  ld a,(ix+ent.state)           ; still walking to the noise
  cp ST_IDLE
  ret nz
  ld a,(tick)                   ; every 4th tick (AI runs every 2nd)
  and 2
  ret nz
  dec (ix+ent.ai_timer)
  ret nz
  jr ai_resume_patrol

ai_do_suspicious:
  call guard_look
  jr nc,.lost
  ld (ix+ent.ai_seen),a
  call face_target
  dec (ix+ent.ai_timer)
  ret nz
  jp raise_alarm
.lost:
  ; keep staring at the last position for a while, then carry on
  ld a,(ix+ent.ai_timer)
  cp SUSPECT_TICKS
  jr c,.cool
  ld (ix+ent.ai_timer),SUSPECT_TICKS
.cool:
  dec (ix+ent.ai_timer)
  ret nz
ai_resume_patrol:
  ld (ix+ent.ai),AI_PATROL
  ld (ix+ent.state),ST_WALK
  jp guard_load_waypoint

ai_do_alarm:
  ld a,(ix+ent.ai_seen)
  cp CMD_COUNT
  jr c,.target
  ; no live target yet: look for one
  call guard_look
  ret nc
  cp CMD_COUNT
  ret nc
  ld (ix+ent.ai_seen),a
.target:
  ld a,(ix+ent.ai_seen)
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  bit EF_DEAD,(iy+ent.flags)
  jr nz,.retarget
  call face_target
  ld a,(ix+ent.fire)
  or a
  jr z,.shoot
  dec (ix+ent.fire)
  ret
.shoot:
  ld (ix+ent.fire),FIRE_TICKS
  call guard_sees_iy            ; only hit what is actually visible
  ret nc
  ld a,SFX_SHOT
  call sfx_play
  ld a,(iy+ent.hp)
  sub SHOT_DAMAGE
  jr nc,.hurt
  xor a
.hurt:
  ld (iy+ent.hp),a
  push af
  call hud_mark_dirty
  pop af
  or a
  ret nz
  push ix
  push iy
  pop ix
  call kill_ent
  pop ix
  ret
.retarget:
  ld (ix+ent.ai_seen),&FF
  ret

raise_alarm:
  ld (ix+ent.ai),AI_ALARM
  ld (ix+ent.state),ST_IDLE
  ld (ix+ent.fire),FIRE_TICKS/2
  ld a,(alarm)
  or a
  ret nz
  ld a,1
  ld (alarm),a
  ld a,SFX_ALARM
  call sfx_play
  ; every other living guard joins the fight
  push ix
  ld a,GUARD_FIRST
.all:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_GUARD
  jr nz,.skip
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.skip
  ld a,(ix+ent.ai)
  cp AI_ALARM
  jr z,.skip
  ld (ix+ent.ai),AI_ALARM
  ld (ix+ent.ai_seen),&FF
  ld (ix+ent.state),ST_IDLE
.skip:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.all
  pop ix
  jp hud_mark_dirty

; ---------------------------------------------------------------------------
; IX = guard. Looks for living commandos, then corpses of other guards.
; -> carry set and A = entity index of the first thing noticed.
; ---------------------------------------------------------------------------
guard_look:
  xor a
.lp:
  ld (look_idx),a
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  ld a,(iy+ent.type)
  or a
  jr z,.next
  push iy
  pop hl
  push ix
  pop de
  or a
  sbc hl,de
  jr z,.next                    ; itself
  ld a,(iy+ent.type)
  cp ET_COMMANDO
  jr z,.cmd
  ; another guard: only interesting if dead
  bit EF_DEAD,(iy+ent.flags)
  jr z,.next
  call guard_sees_iy_short
  jr c,.found
  jr .next
.cmd:
  bit EF_DEAD,(iy+ent.flags)
  jr nz,.next
  call guard_sees_iy
  jr c,.found
.next:
  ld a,(look_idx)
  inc a
  cp MAX_ENTS
  jr nz,.lp
  or a
  ret
.found:
  ld a,(look_idx)
  scf
  ret

; IX = guard, IY = commando. Carry = seen (zone rules + LOS).
guard_sees_iy:
  bit EF_CRAWL,(iy+ent.flags)
  jr nz,guard_sees_iy_short
  ld a,LONG_R
  jr guard_sees_r
guard_sees_iy_short:
  ld a,SHORT_R
guard_sees_r:
  ld (look_r),a
  call vis_vector
  jr c,.no
  call vis_distance
  ld b,a
  ld a,(look_r)
  cp b
  jr c,.no                      ; beyond range
  call vis_angle
  ld b,a
  ld a,(ix+ent.dir)
  rrca                          ; dir * 32
  rrca
  rrca
  sub b
  call abs_a
  cp CONE_HALF+1
  jr nc,.no
  call los_clear
  ccf
  ret
.no:
  or a
  ret

; IX = guard faces IY (8-way)
face_target:
  ld a,(ix+ent.ai_seen)
  cp MAX_ENTS
  ret nc
  push ix
  call ent_ptr
  push ix
  pop iy
  pop ix
  call vis_vector
  ret c
  call vis_distance
  call vis_angle
  add a,16                      ; round to the nearest octant
  rlca
  rlca
  rlca
  and 7
  ld (ix+ent.dir),a
  ret
