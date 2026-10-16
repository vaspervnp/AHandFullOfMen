#!/usr/bin/env bash
# Art pipeline: Blender scenes + Aseprite documents -> the PNG sheets in
# assets/ that ./build.sh converts. Run whenever art changes; the outputs
# are committed, so normal builds need neither Blender nor Aseprite.
#
# Sources of truth
#   assets/blender/*.blend      3D: operatives, sentry, radio tower, pine,
#                               rock, barrel, bear trap, time bomb, explosion,
#                               truck, fuel depot, portraits, title banner (created by the render script
#                               on first run, then edited in Blender)
#   assets/aseprite/terrain.aseprite  8x8 terrain/building/HUD tiles (the
#                               prop cells hold the ground under the props)
#   assets/aseprite/font.aseprite     4x8 HUD font
#   assets/aseprite/cursor.aseprite   crosshair, attack marker, ! ? icons, decoy
#
# Steps
#   1. Blender (headless) renders every subject (tools/blender/hfm_render.py)
#   2. Aseprite exports the hand-drawn documents
#   3. renders2sheet / assemble_art pixelize renders (8x4 block mode filter),
#      outline, mirror west frames, composite props onto the terrain tiles
#   4. Aseprite clamps every generated sheet to the CPC palette (2:1 pixel
#      ratio) and saves an editable copy next to the PNG it exports
#
# Env overrides: BLENDER, ASEPRITE (Windows executables reached through WSL).
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
ASEPRITE="${ASEPRITE:-/mnt/c/Users/vasilhs/source/repos/aseprite/build/bin/aseprite.exe}"
winpath() { wslpath -w "$1"; }
clamp() {  # <in.png> <out.aseprite> <out.png>
  "$ASEPRITE" -b --script-param "in=$(winpath "$1")" --script-param "ase=$(winpath "$2")" \
    --script-param "png=$(winpath "$3")" --script "$(winpath tools/aseprite/cpc_palette.lua)" \
    | sed 's/.*-> /aseprite: /'
}
export_ase() {  # <in.aseprite> <out.png>
  "$ASEPRITE" -b "$(winpath "$1")" --save-as "$(winpath "$2")"
  echo "aseprite: $1 -> $2"
}

mkdir -p build/art assets/renders assets/aseprite assets/blender assets/sprites3
"$BLENDER" -b --factory-startup --python "$(winpath tools/blender/hfm_render.py)" \
  -- "$(winpath assets/renders)" "$(winpath assets/blender)" 2>&1 | grep -E "HFM_RENDERED|Error|Traceback"

export_ase assets/aseprite/terrain.aseprite build/art/terrain.png
export_ase assets/aseprite/font.aseprite assets/ui/font.png
export_ase assets/aseprite/cursor.aseprite assets/sprites/cursor.png

for spec in sprites:beret sprites:guard sprites2:marine sprites2:sniper sprites3:sapper sprites3:spy; do
  folder=${spec%%:*}; name=${spec##*:}
  python3 tools/renders2sheet.py assets/renders "$name" "build/art/${name}.png"
  clamp "build/art/${name}.png" "assets/aseprite/${name}.aseprite" "assets/${folder}/${name}.png"
done

python3 tools/assemble_art.py build/art/terrain.png assets/renders build/art
clamp build/art/norway.png assets/aseprite/norway.aseprite assets/tiles/norway.png
clamp build/art/fx.png assets/aseprite/fx.aseprite assets/sprites/fx.png
clamp build/art/portraits.png assets/aseprite/portraits.aseprite assets/ui/portraits.png
clamp build/art/title.png assets/aseprite/title.aseprite assets/ui/title.png
echo "render_assets: done"
