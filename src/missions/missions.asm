; ===========================================================================
; Mission table. Each mission's block (descriptor, texts, briefing, spawns,
; routes: src/missions/missionNN.asm) lives in RAM bank 7, assembled for the
; address mis_buf. mission_select copies the chosen block into mis_buf and
; its descriptor into mis; the rest of the game only reads those.
; ===========================================================================

; descriptor fields: MIS_* in src/defs.asm
MISSION_COUNT   equ 8           ; the seven missions, then training
TUTORIAL        equ 7           ; Boot Camp: key 0, leads on to mission 1
MIS_BUF_SIZE    equ 18*MAP_W    ; copied MAP_W bytes at a time via bounce

mission_table:                  ; where each block sits in bank 7
  dw mis_phys_1, mis_phys_2, mis_phys_3, mis_phys_4, mis_phys_5, mis_phys_6, mis_phys_7, mis_phys_8
