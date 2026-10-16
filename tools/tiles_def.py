"""Tile ids of the Norway tile sheet. Order matters: tools/map2asm.py uses
these names for the map legend and src/data/tileattrs.asm lists the flags in
the same order. Cells are 8x8, sheet is 8 tiles wide."""

TILE_NAMES = [
    "snow", "snow_speck", "snow_shade", "road", "ice", "water", "bank_n", "bank_s",
    "rock", "fence_h", "fence_v", "wall", "roof", "roof_edge", "door", "bridge",
    "sandbag", "tracks",
    "pine0", "pine1", "pine2", "pine3", "pine4", "pine5",          # 2x3 stamp
    "tower0", "tower1", "tower2", "tower3", "tower4", "tower5", "tower6", "tower7",  # 2x4
    "rubble", "gate", "hud_bg", "hud_edge",
    "truck0", "truck1", "truck2", "truck3", "truck4", "truck5",     # 3x2 stamp
    "scorch",
    "depot0", "depot1", "depot2", "depot3", "depot4", "depot5",     # 3x2 stamp
] + [f"uboat{i}" for i in range(96)] + [                          # 16x6 stamp
    "rbridge0", "rbridge1", "rbridge2", "rbridge3", "rbridge4", "rbridge5",  # 4x3 stamp
    "rbridge6", "rbridge7", "rbridge8", "rbridge9", "rbridge10", "rbridge11",
    "rail_l", "rail_r",                                             # railway, 2 tiles wide
] + [f"gun{i}" for i in range(12)] + [                            # 4x3 coastal gun stamp
    f"plant{i}" for i in range(12)]                                 # 4x3 heavy water plant

# Multi-tile props rendered in Blender and composited onto the ground
# painted in assets/aseprite/terrain.aseprite: name -> (first tile, w, h)
STAMPS = {"pine": ("pine0", 2, 3), "tower": ("tower0", 2, 4), "truck": ("truck0", 3, 2),
          "rock": ("rock", 1, 1), "depot": ("depot0", 3, 2), "uboat": ("uboat0", 16, 6),
          "railbridge": ("rbridge0", 4, 3),
          "gun": ("gun0", 4, 3),
          "plant": ("plant0", 4, 3)}
# Stamp cells not painted in terrain.aseprite get this ground underneath.
STAMP_GROUND = {"uboat": "water", "railbridge": "water"}
SHEET_COLS = 8
