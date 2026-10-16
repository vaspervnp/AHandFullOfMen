; ===========================================================================
; Tile attribute flags, indexed by tile id (order = TILE_NAMES in
; tools/tiles_def.py)
; ===========================================================================

TILE_RUBBLE     equ 32
TILE_TOWER0     equ 24
TILE_SNOW       equ 0
TILE_SCORCH     equ 42

  align 256                     ; pathfinder indexes it by H=page, L=tile
tile_attrs:
  db TF_SNOW                    ; 0  snow
  db TF_SNOW                    ; 1  snow_speck
  db TF_SNOW                    ; 2  snow_shade
  db 0                          ; 3  road
  db 0                          ; 4  ice
  db TF_WATER                   ; 5  water
  db TF_WATER                   ; 6  bank_n
  db TF_WATER                   ; 7  bank_s
  db TF_SOLID|TF_OPAQUE         ; 8  rock
  db TF_SOLID                   ; 9  fence_h
  db TF_SOLID                   ; 10 fence_v
  db TF_SOLID|TF_OPAQUE         ; 11 wall
  db TF_SOLID|TF_OPAQUE         ; 12 roof
  db TF_SOLID|TF_OPAQUE         ; 13 roof_edge
  db TF_SOLID|TF_OPAQUE         ; 14 door
  db 0                          ; 15 bridge
  db TF_SOLID                   ; 16 sandbag
  db TF_SNOW                    ; 17 tracks
  db TF_SNOW                    ; 18 pine0 (top, canopy)
  db TF_SNOW                    ; 19 pine1
  db TF_SOLID|TF_OPAQUE         ; 20 pine2
  db TF_SOLID|TF_OPAQUE         ; 21 pine3
  db TF_SOLID|TF_OPAQUE         ; 22 pine4 (trunk)
  db TF_SOLID|TF_OPAQUE         ; 23 pine5
  db 0                          ; 24 tower0
  db 0                          ; 25 tower1
  db TF_SOLID                   ; 26 tower2
  db TF_SOLID                   ; 27 tower3
  db TF_SOLID                   ; 28 tower4
  db TF_SOLID                   ; 29 tower5
  db TF_SOLID                   ; 30 tower6
  db TF_SOLID                   ; 31 tower7
  db TF_SNOW                    ; 32 rubble
  db 0                          ; 33 gate (barrier raised)
  db TF_SOLID                   ; 34 hud_bg
  db TF_SOLID                   ; 35 hud_edge
  db TF_OPAQUE                  ; 36 truck0 (walk in to board)
  db TF_OPAQUE                  ; 37 truck1
  db TF_OPAQUE                  ; 38 truck2
  db TF_OPAQUE                  ; 39 truck3
  db TF_OPAQUE                  ; 40 truck4
  db TF_OPAQUE                  ; 41 truck5
  db 0                          ; 42 scorch
  db TF_SOLID|TF_OPAQUE         ; 43 depot0 (fuel tanks, 3x2)
  db TF_SOLID|TF_OPAQUE         ; 44 depot1
  db TF_SOLID|TF_OPAQUE         ; 45 depot2
  db TF_SOLID|TF_OPAQUE         ; 46 depot3
  db TF_SOLID|TF_OPAQUE         ; 47 depot4
  db TF_SOLID|TF_OPAQUE         ; 48 depot5
