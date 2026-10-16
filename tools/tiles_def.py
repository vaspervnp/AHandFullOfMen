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
]

# Multi-tile props rendered in Blender and composited onto the ground
# painted in assets/aseprite/terrain.aseprite: name -> (first tile, w, h)
STAMPS = {"pine": ("pine0", 2, 3), "tower": ("tower0", 2, 4), "truck": ("truck0", 3, 2),
          "rock": ("rock", 1, 1)}
SHEET_COLS = 8
