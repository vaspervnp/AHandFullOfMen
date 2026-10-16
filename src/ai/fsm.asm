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
  call guard_load_waypoint
  ld b,(ix+ent.tx)              ; find the way back to the patrol route
  ld c,(ix+ent.ty)
  ld a,TF_SOLID|TF_WATER
  jp path_to

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
  ld a,(iy+ent.flags)
  and (1<<EF_DEAD)|(1<<EF_BOARDED)
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
  jp alarm_all

; ---------------------------------------------------------------------------
; IX = guard. Looks for living commandos, then corpses of other guards.
; -> carry set and A = entity index of the first thing noticed.
; ---------------------------------------------------------------------------
guard_look:
  ld iy,ent_table
  xor a
.lp:
  ld (look_idx),a
  cp (ix+ent.idx)
  jr z,.next                    ; itself
  ld a,(iy+ent.type)
  cp ET_COMMANDO
  jr z,.cmd
  cp ET_GUARD
  jr nz,.next
  ; another guard: only interesting if dead
  bit EF_DEAD,(iy+ent.flags)
  jr z,.next
  call guard_sees_iy_short
  jr c,.found
  jr .next
.cmd:
  ld a,(iy+ent.flags)
  and (1<<EF_DEAD)|(1<<EF_BOARDED)
  jr nz,.next
  call guard_sees_iy
  jr c,.found
.next:
  ld de,ENT_SIZE
  add iy,de
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
  ld b,(iy+ent.x)               ; underwater (the Marine) = invisible
  ld c,(iy+ent.y)
  call map_flags
  and TF_WATER
  ret nz                        ; NC: not seen
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
