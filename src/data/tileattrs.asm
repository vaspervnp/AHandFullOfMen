; ===========================================================================
; Tile attribute flags, indexed by tile id (order = TILE_NAMES in
; tools/tiles_def.py)
; ===========================================================================

TILE_RUBBLE     equ 32
TILE_TOWER0     equ 24
TILE_SNOW       equ 0
TILE_WATER      equ 5
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
  db TF_SOLID|TF_OPAQUE         ; 49 uboat0 (16x6, in the water)
  db TF_SOLID|TF_OPAQUE         ; 50 uboat1
  db TF_SOLID|TF_OPAQUE         ; 51 uboat2
  db TF_SOLID|TF_OPAQUE         ; 52 uboat3
  db TF_SOLID|TF_OPAQUE         ; 53 uboat4
  db TF_SOLID|TF_OPAQUE         ; 54 uboat5
  db TF_SOLID|TF_OPAQUE         ; 55 uboat6
  db TF_SOLID|TF_OPAQUE         ; 56 uboat7
  db TF_SOLID|TF_OPAQUE         ; 57 uboat8
  db TF_SOLID|TF_OPAQUE         ; 58 uboat9
  db TF_SOLID|TF_OPAQUE         ; 59 uboat10
  db TF_SOLID|TF_OPAQUE         ; 60 uboat11
  db TF_SOLID|TF_OPAQUE         ; 61 uboat12
  db TF_SOLID|TF_OPAQUE         ; 62 uboat13
  db TF_SOLID|TF_OPAQUE         ; 63 uboat14
  db TF_SOLID|TF_OPAQUE         ; 64 uboat15
  db TF_SOLID|TF_OPAQUE         ; 65 uboat16
  db TF_SOLID|TF_OPAQUE         ; 66 uboat17
  db TF_SOLID|TF_OPAQUE         ; 67 uboat18
  db TF_SOLID|TF_OPAQUE         ; 68 uboat19
  db TF_SOLID|TF_OPAQUE         ; 69 uboat20
  db TF_SOLID|TF_OPAQUE         ; 70 uboat21
  db TF_SOLID|TF_OPAQUE         ; 71 uboat22
  db TF_SOLID|TF_OPAQUE         ; 72 uboat23
  db TF_SOLID|TF_OPAQUE         ; 73 uboat24
  db TF_SOLID|TF_OPAQUE         ; 74 uboat25
  db TF_SOLID|TF_OPAQUE         ; 75 uboat26
  db TF_SOLID|TF_OPAQUE         ; 76 uboat27
  db TF_SOLID|TF_OPAQUE         ; 77 uboat28
  db TF_SOLID|TF_OPAQUE         ; 78 uboat29
  db TF_SOLID|TF_OPAQUE         ; 79 uboat30
  db TF_SOLID|TF_OPAQUE         ; 80 uboat31
  db TF_SOLID|TF_OPAQUE         ; 81 uboat32
  db TF_SOLID|TF_OPAQUE         ; 82 uboat33
  db TF_SOLID|TF_OPAQUE         ; 83 uboat34
  db TF_SOLID|TF_OPAQUE         ; 84 uboat35
  db TF_SOLID|TF_OPAQUE         ; 85 uboat36
  db TF_SOLID|TF_OPAQUE         ; 86 uboat37
  db TF_SOLID|TF_OPAQUE         ; 87 uboat38
  db TF_SOLID|TF_OPAQUE         ; 88 uboat39
  db TF_SOLID|TF_OPAQUE         ; 89 uboat40
  db TF_SOLID|TF_OPAQUE         ; 90 uboat41
  db TF_SOLID|TF_OPAQUE         ; 91 uboat42
  db TF_SOLID|TF_OPAQUE         ; 92 uboat43
  db TF_SOLID|TF_OPAQUE         ; 93 uboat44
  db TF_SOLID|TF_OPAQUE         ; 94 uboat45
  db TF_SOLID|TF_OPAQUE         ; 95 uboat46
  db TF_SOLID|TF_OPAQUE         ; 96 uboat47
  db TF_SOLID|TF_OPAQUE         ; 97 uboat48
  db TF_SOLID|TF_OPAQUE         ; 98 uboat49
  db TF_SOLID|TF_OPAQUE         ; 99 uboat50
  db TF_SOLID|TF_OPAQUE         ; 100 uboat51
  db TF_SOLID|TF_OPAQUE         ; 101 uboat52
  db TF_SOLID|TF_OPAQUE         ; 102 uboat53
  db TF_SOLID|TF_OPAQUE         ; 103 uboat54
  db TF_SOLID|TF_OPAQUE         ; 104 uboat55
  db TF_SOLID|TF_OPAQUE         ; 105 uboat56
  db TF_SOLID|TF_OPAQUE         ; 106 uboat57
  db TF_SOLID|TF_OPAQUE         ; 107 uboat58
  db TF_SOLID|TF_OPAQUE         ; 108 uboat59
  db TF_SOLID|TF_OPAQUE         ; 109 uboat60
  db TF_SOLID|TF_OPAQUE         ; 110 uboat61
  db TF_SOLID|TF_OPAQUE         ; 111 uboat62
  db TF_SOLID|TF_OPAQUE         ; 112 uboat63
  db TF_SOLID|TF_OPAQUE         ; 113 uboat64
  db TF_SOLID|TF_OPAQUE         ; 114 uboat65
  db TF_SOLID|TF_OPAQUE         ; 115 uboat66
  db TF_SOLID|TF_OPAQUE         ; 116 uboat67
  db TF_SOLID|TF_OPAQUE         ; 117 uboat68
  db TF_SOLID|TF_OPAQUE         ; 118 uboat69
  db TF_SOLID|TF_OPAQUE         ; 119 uboat70
  db TF_SOLID|TF_OPAQUE         ; 120 uboat71
  db TF_SOLID|TF_OPAQUE         ; 121 uboat72
  db TF_SOLID|TF_OPAQUE         ; 122 uboat73
  db TF_SOLID|TF_OPAQUE         ; 123 uboat74
  db TF_SOLID|TF_OPAQUE         ; 124 uboat75
  db TF_SOLID|TF_OPAQUE         ; 125 uboat76
  db TF_SOLID|TF_OPAQUE         ; 126 uboat77
  db TF_SOLID|TF_OPAQUE         ; 127 uboat78
  db TF_SOLID|TF_OPAQUE         ; 128 uboat79
  db TF_SOLID|TF_OPAQUE         ; 129 uboat80
  db TF_SOLID|TF_OPAQUE         ; 130 uboat81
  db TF_SOLID|TF_OPAQUE         ; 131 uboat82
  db TF_SOLID|TF_OPAQUE         ; 132 uboat83
  db TF_SOLID|TF_OPAQUE         ; 133 uboat84
  db TF_SOLID|TF_OPAQUE         ; 134 uboat85
  db TF_SOLID|TF_OPAQUE         ; 135 uboat86
  db TF_SOLID|TF_OPAQUE         ; 136 uboat87
  db TF_SOLID|TF_OPAQUE         ; 137 uboat88
  db TF_SOLID|TF_OPAQUE         ; 138 uboat89
  db TF_SOLID|TF_OPAQUE         ; 139 uboat90
  db TF_SOLID|TF_OPAQUE         ; 140 uboat91
  db TF_SOLID|TF_OPAQUE         ; 141 uboat92
  db TF_SOLID|TF_OPAQUE         ; 142 uboat93
  db TF_SOLID|TF_OPAQUE         ; 143 uboat94
  db TF_SOLID|TF_OPAQUE         ; 144 uboat95
