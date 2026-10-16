#!/usr/bin/env bash
# 3D -> 8-bit art pipeline (Milestone 1). Regenerates the committed PNGs in
# assets/; ./build.sh only consumes them, so this runs only when art changes.
#
#   1. Blender (headless): low-poly models -> flat-shaded renders, 5 directions
#      x 7 poses per character + the radio tower  (tools/blender/hfm_render.py)
#   2. renders2sheet: 8x4-block mode filter -> 12x16 Mode 0 cells, outline,
#      mirrored west-facing frames, game sheet layout
#   3. Aseprite (batch): clamp to the 16-colour CPC palette, 2:1 pixel ratio,
#      save editable assets/aseprite/*.aseprite + export the sheet PNG
#   4. gen_art: tiles (tower stamp from its render), UI, effects
#
# Env overrides: BLENDER, ASEPRITE (Windows executables reached through WSL).
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
ASEPRITE="${ASEPRITE:-/mnt/c/Users/vasilhs/source/repos/aseprite/build/bin/aseprite.exe}"
winpath() { wslpath -w "$1"; }

mkdir -p build assets/renders assets/aseprite
"$BLENDER" -b --factory-startup --python "$(winpath tools/blender/hfm_render.py)" \
  -- "$(winpath assets/renders)" 2>&1 | grep -E "HFM_RENDERED|Error|Traceback"

for spec in sprites:beret sprites:guard sprites2:marine sprites2:sniper; do
  folder=${spec%%:*}; name=${spec##*:}
  python3 tools/renders2sheet.py assets/renders "$name" "build/${name}_raw.png"
  "$ASEPRITE" -b \
    --script-param "in=$(winpath "build/${name}_raw.png")" \
    --script-param "ase=$(winpath "assets/aseprite/${name}.aseprite")" \
    --script-param "png=$(winpath "assets/${folder}/${name}.png")" \
    --script "$(winpath tools/aseprite/cpc_palette.lua)"
done
python3 tools/gen_art.py
echo "render_assets: done (assets/sprites*, assets/tiles, assets/aseprite)"
