#!/usr/bin/env bash
# Release build: full build + every test (cpcsim and Caprice32), a fuzz soak,
# then versioned images in dist/:
#   dist/a_handful_of_men-<version>.dsk   bootable disk: RUN"DISC
#   dist/a_handful_of_men-<version>.sna   snapshot (128K, starts at the title)
#   dist/SHA256SUMS
# <version> is `git describe --tags --always --dirty`.
#   tools/release.sh [--seeds 1-4] [--ticks 3000]
set -euo pipefail
cd "$(dirname "$0")/.."
SEEDS=1-4
TICKS=3000
while [[ $# -gt 0 ]]; do
  case "$1" in
    --seeds) SEEDS="$2"; shift 2 ;;
    --ticks) TICKS="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

./build.sh
tests/fuzz.py --seeds "$SEEDS" --ticks "$TICKS"

VERSION=$(git describe --tags --always --dirty)
mkdir -p dist
rm -f dist/a_handful_of_men-*.dsk dist/a_handful_of_men-*.sna dist/SHA256SUMS
cp build/handful_of_men.dsk "dist/a_handful_of_men-$VERSION.dsk"
cp build/handful_of_men.sna "dist/a_handful_of_men-$VERSION.sna"
(cd dist && sha256sum a_handful_of_men-* > SHA256SUMS)
echo "release: $VERSION"
cat dist/SHA256SUMS
