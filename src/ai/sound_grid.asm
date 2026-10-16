; ===========================================================================
; Noise propagation
;
; A noise at world (B, C) with a radius in visual units (scanlines) sends
; every calm guard within earshot to investigate the spot. Guards already
; suspicious or in combat ignore it.
; ===========================================================================

NOISE_STEPS     equ 20          ; footsteps on snow
NOISE_DECOY     equ 72          ; radio decoy ping
NOISE_SHOT      equ 120         ; gunfire
INVESTIGATE_T   equ 62          ; ~10 s (timer runs every 4th tick)
DECOY_HOLD_T    equ 156         ; ~25 s
FOOTSTEP_EVERY  equ 8           ; ticks between footstep noises

; B = x, C = y, A = radius, E = investigate time
noise_emit:
  ld (noise_r),a
  ld a,e
  ld (noise_t),a
  ld a,b
  ld (noise_x),a
  ld a,c
  ld (noise_y),a
  push ix
  ld a,GUARD_FIRST
.lp:
  push af
  call ent_ptr
  ld a,(ix+ent.type)
  cp ET_GUARD
  jr nz,.next
  bit EF_DEAD,(ix+ent.flags)
  jr nz,.next
  ld a,(ix+ent.ai)
  cp AI_SUSPICIOUS
  jr nc,.next                   ; suspicious / alarm: busy
  ld a,(noise_x)
  ld b,a
  ld a,(noise_y)
  ld c,a
  call vis_vector_pt
  jr c,.next
  call vis_distance
  ld b,a
  ld a,(noise_r)
  cp b
  jr c,.next
  ; go and look, if there is a way there
  ld a,(noise_x)
  ld b,a
  ld a,(noise_y)
  ld c,a
  ld a,TF_SOLID|TF_WATER
  call path_to
  jr nc,.next
  ld (ix+ent.ai),AI_INVESTIGATE
  ld a,(noise_t)
  ld (ix+ent.ai_timer),a
  ld (ix+ent.state),ST_WALK
  ld (ix+ent.timer),0
.next:
  pop af
  inc a
  cp MAX_ENTS
  jr nz,.lp
  pop ix
  ret

; IX = walking commando: standing on snow makes footstep noise.
footsteps:
  bit EF_CRAWL,(ix+ent.flags)
  ret nz
  ld a,(tick)
  and FOOTSTEP_EVERY-1
  ret nz
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  push bc
  call map_flags
  pop bc
  and TF_SNOW
  ret z
  ld a,NOISE_STEPS
  ld e,INVESTIGATE_T
  jp noise_emit

; ---------------------------------------------------------------------------
; Green Beret radio decoy (entity DECOY_ENT). D drops it at his feet; D again
; makes it ping.
; ---------------------------------------------------------------------------
DECOY_ENT       equ MAX_ENTS-1

decoy_key:
  call sel_ent
  ld a,(ix+ent.role)
  cp ROLE_BERET
  ret nz
  bit EF_DEAD,(ix+ent.flags)
  ret nz
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  ld a,DECOY_ENT
  call ent_ptr
  ld a,(ix+ent.type)
  or a
  jr nz,decoy_ping
  ; B, C = drop position
decoy_place:
  ld a,DECOY_ENT
  call ent_ptr
  ld (ix+ent.type),ET_DECOY
  ld (ix+ent.x),b
  ld (ix+ent.y),c
  ld (ix+ent.idx),DECOY_ENT
  ret

decoy_ping:
  ld a,SFX_DECOY
  call sfx_play
  ld b,(ix+ent.x)
  ld c,(ix+ent.y)
  ld a,NOISE_DECOY
  ld e,DECOY_HOLD_T
  jp noise_emit
