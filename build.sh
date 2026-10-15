#!/usr/bin/env bash
# A Handful of Men - full build: assets -> RASM -> .sna + .dsk -> tests
#
#   ./build.sh           build everything and run the headless tests
#   ./build.sh --no-test build only
set -euo pipefail
cd "$(dirname "$0")"

RUN_TESTS=1
[[ "${1:-}" == "--no-test" ]] && RUN_TESTS=0

RASM="rasm -amper -v2 -I../src -I."

# 1. Clean previous build artifacts
rm -rf build && mkdir -p build

# 2. Art assets -> Mode 0 data (assets/*.png are committed; regenerate the
#    placeholders with tools/gen_art.py, or drop in Blender/Aseprite renders)
python3 tools/png2cpc.py assets/sprites build/sprites.asm
python3 tools/png2cpc.py assets/sprites2 build/sprites2.asm
python3 tools/png2cpc.py assets/tiles build/tiles.asm
python3 tools/png2cpc.py assets/ui build/ui.asm
python3 tools/map2asm.py assets/maps/mission01.txt map_mission01 build/mission01_map.asm

cd build

# 3. Core game: code.bin / data.bin / sprites.bin + snapshot + symbols
$RASM ../src/main.asm -oi handful_of_men.sna -os handful_of_men.sym -s -sl 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' | tee rasm.log | grep -E "error|warning|Write binary" || true
if grep -qiE "error|warning" rasm.log; then echo "build: rasm reported problems"; exit 1; fi

# 4. Disk loader
rasm -amper ../src/boot/loader.asm -ob loader.bin 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > loader.log
if grep -qiE "error|warning" loader.log; then cat loader.log; exit 1; fi

# 5. Bootable DSK (RUN"DISC)
iDSK handful_of_men.dsk -n >/dev/null 2>&1
cp ../assets/revive8b.scr SPLASH.SCR
cp loader.bin LOADER.BIN
cp code.bin CODE.BIN
cp data.bin DATA.BIN
cp sprites.bin SPRITES.BIN
cp sprites2.bin SPRITES2.BIN
cp ../assets/disc/DISC.BAS DISC.BAS
iDSK handful_of_men.dsk -i DISC.BAS -t 0 >/dev/null 2>&1
iDSK handful_of_men.dsk -i SPLASH.SCR -t 1 -e C000 -c C000 >/dev/null 2>&1
iDSK handful_of_men.dsk -i LOADER.BIN -t 1 -e 9000 -c 9000 >/dev/null 2>&1
iDSK handful_of_men.dsk -i CODE.BIN -t 1 -e 0040 -c 0040 >/dev/null 2>&1
iDSK handful_of_men.dsk -i DATA.BIN -t 1 -e 4000 -c 4000 >/dev/null 2>&1
iDSK handful_of_men.dsk -i SPRITES.BIN -t 1 -e 4000 -c 4000 >/dev/null 2>&1
iDSK handful_of_men.dsk -i SPRITES2.BIN -t 1 -e 4000 -c 4000 >/dev/null 2>&1
echo "build: handful_of_men.sna + handful_of_men.dsk ready in build/"

# 6. Headless regression tests
if [[ $RUN_TESTS == 1 ]]; then
  cd ..
  tests/run_tests.sh
fi
