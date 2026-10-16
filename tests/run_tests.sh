#!/usr/bin/env bash
# Assemble every tests/tNN_*.asm scenario, check it in the Python simulator
# (tests/check.py assertions), then run it in Caprice32 for a screenshot.
#   tests/run_tests.sh [--no-cap32]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
CAP32=1
[[ "${1:-}" == "--no-cap32" ]] && CAP32=0

fail=0
for src in tests/t[0-9][0-9]_*.asm; do
  name=$(basename "$src" .asm)
  (cd build && rasm -amper -v2 -I../src -I. "../$src" \
      -oi "tests/$name.sna" -os "tests/$name.sym" -s -sl 2>&1 \
      | sed 's/\x1b\[[0-9;]*m//g' > "tests/$name.log") || true
  (cd build && rasm -amper -v2 -I../src -I. -DREF_RENDER=1 "../$src" \
      -oi "tests/${name}_ref.sna" -os "tests/${name}_ref.sym" -s -sl 2>&1 \
      | sed 's/\x1b\[[0-9;]*m//g' >> "tests/$name.log") || true
  if grep -qiE "error|warning" "build/tests/$name.log"; then
    echo "FAIL $name (assembly)"; grep -iE "error|warning" "build/tests/$name.log"; fail=1; continue
  fi
  if ! python3 tests/check.py "$name"; then fail=1; continue; fi
  if [[ $CAP32 == 1 ]]; then
    if ! tools/cpcemu -timeout 60 -shot "$PWD/build/tests/$name.png" "build/tests/$name.sna" >/dev/null; then
      echo "FAIL $name (Caprice32 never reached the end of the script)"; fail=1; continue
    fi
  fi
  echo "ok   $name"
done
# Disk boot: RUN"DISC -> splash -> loader -> game (screenshot only; the
# release build has no end-of-test hook, so we pad time with ignored keys)
if [[ $CAP32 == 1 ]]; then
  PAD=$(printf 'z%.0s' $(seq 1 250))
  if tools/cpcemu -timeout 120 -nowait -keys "run\"disc"$'\n'"$PAD" \
       -shot "$PWD/build/tests/dsk_boot.png" build/handful_of_men.dsk >/dev/null; then
    echo "ok   dsk_boot (see build/tests/dsk_boot.png)"
  else
    echo "FAIL dsk_boot"; fail=1
  fi
  # ... and into the mission: SPACE at the menu and the briefing, then the HUD
  if tools/cpcemu -timeout 300 -nowait -keys "run\"disc"$'\n'"$PAD$PAD $PAD $PAD" \
       -shot "$PWD/build/tests/dsk_play.png" build/handful_of_men.dsk >/dev/null \
     && python3 -c "
from PIL import Image
im = Image.open('build/tests/dsk_play.png').convert('RGB')
r, g, b = im.getpixel((100, 470))          # HUD panel, below the portraits
raise SystemExit(0 if b > 200 and r < 60 and g < 60 else 1)"; then
    echo "ok   dsk_play (see build/tests/dsk_play.png)"
  else
    echo "FAIL dsk_play"; fail=1
  fi
  # ... and on a 64K CPC 664 the loader explains it needs 128K instead
  if tools/cpcemu -model 1 -ram 64 -timeout 300 -nowait -keys "run\"disc"$'\n'"$PAD$PAD" \
       -shot "$PWD/build/tests/dsk_64k.png" build/handful_of_men.dsk >/dev/null \
     && python3 -c "
from PIL import Image
im = Image.open('build/tests/dsk_64k.png').convert('RGB')
lit = sum(1 for x in range(64, 700) if im.getpixel((x, 92)) != (0, 0, 0))
raise SystemExit(0 if lit > 100 else 1)        # the first line of the message"; then
    echo "ok   dsk_64k (see build/tests/dsk_64k.png)"
  else
    echo "FAIL dsk_64k"; fail=1
  fi
fi
exit $fail
