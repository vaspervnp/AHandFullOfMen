"""Amstrad CPC colour definitions shared by the asset tools.

The Gate Array can show 27 colours. Each has a firmware number (BASIC INK
value) and a hardware number (the value written to the Gate Array after
selecting a pen with &7F00+pen, OR'ed with &40).
"""

# firmware number -> (hardware number, RGB)
FIRMWARE = {
    0: (0x54, (0, 0, 0)),          # Black
    1: (0x44, (0, 0, 128)),        # Blue
    2: (0x55, (0, 0, 255)),        # Bright Blue
    3: (0x5C, (128, 0, 0)),        # Red
    4: (0x58, (128, 0, 128)),      # Magenta
    5: (0x5D, (128, 0, 255)),      # Mauve
    6: (0x4C, (255, 0, 0)),        # Bright Red
    7: (0x45, (255, 0, 128)),      # Purple
    8: (0x4D, (255, 0, 255)),      # Bright Magenta
    9: (0x56, (0, 128, 0)),        # Green
    10: (0x46, (0, 128, 128)),     # Cyan
    11: (0x57, (0, 128, 255)),     # Sky Blue
    12: (0x5E, (128, 128, 0)),     # Yellow
    13: (0x40, (128, 128, 128)),   # White
    14: (0x5F, (128, 128, 255)),   # Pastel Blue
    15: (0x4E, (255, 128, 0)),     # Orange
    16: (0x47, (255, 128, 128)),   # Pink
    17: (0x4F, (255, 128, 255)),   # Pastel Magenta
    18: (0x52, (0, 255, 0)),       # Bright Green
    19: (0x42, (0, 255, 128)),     # Sea Green
    20: (0x53, (0, 255, 255)),     # Bright Cyan
    21: (0x5A, (128, 255, 0)),     # Lime
    22: (0x59, (128, 255, 128)),   # Pastel Green
    23: (0x5B, (128, 255, 255)),   # Pastel Cyan
    24: (0x4A, (255, 255, 0)),     # Bright Yellow
    25: (0x43, (255, 255, 128)),   # Pastel Yellow
    26: (0x4B, (255, 255, 255)),   # Bright White
}

HW_TO_RGB = {hw: rgb for hw, rgb in FIRMWARE.values()}

# The in-game palette (Mission 1, Norway). Index = pen number.
# Keep in sync with src/data/palettes.asm and tools/aseprite/cpc_palette.lua.
GAME_PENS = [
    0,   # 0  Black         outlines
    26,  # 1  Bright White  snow
    23,  # 2  Pastel Cyan   snow shade, ice
    11,  # 3  Sky Blue      water, ice cracks
    1,   # 4  Blue          deep water, night shade
    13,  # 5  White (grey)  rock, metal
    9,   # 6  Green         uniforms, pine needles
    10,  # 7  Cyan          pine shade
    3,   # 8  Red           wood, brick
    15,  # 9  Orange        wood highlight, fire
    16,  # 10 Pink          skin
    12,  # 11 Yellow        German field grey (olive)
    6,   # 12 Bright Red    alarm, blood
    24,  # 13 Bright Yellow vision cone, muzzle flash
    2,   # 14 Bright Blue   HUD panel
    25,  # 15 Pastel Yellow lamps, HUD text
]

GAME_RGB = [FIRMWARE[f][1] for f in GAME_PENS]
GAME_HW = [FIRMWARE[f][0] for f in GAME_PENS]

TRANSPARENT = (255, 0, 255)   # magenta key colour in source PNGs (not in GAME_RGB)


def mode0_byte(p0, p1):
    """Pack two Mode 0 pens (left, right) into one screen byte.

    Hardware layout: left pixel bits 0..3 live in bits 7,3,5,1;
    right pixel bits 0..3 live in bits 6,2,4,0.
    """
    def spread(p):
        return ((p & 1) << 7) | ((p & 2) << 2) | ((p & 4) << 3) | ((p & 8) >> 2)
    return spread(p0) | (spread(p1) >> 1)


def mode0_unpack(b):
    def gather(v):
        return ((v >> 7) & 1) | (((v >> 3) & 1) << 1) | (((v >> 5) & 1) << 2) | (((v >> 1) & 1) << 3)
    return gather(b), gather((b << 1) & 0xFF)


assert mode0_unpack(mode0_byte(5, 10)) == (5, 10)
assert all(mode0_unpack(mode0_byte(a, b)) == (a, b) for a in range(16) for b in range(16))
