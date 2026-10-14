#!/usr/bin/env bash
# capture_m3_9_evidence.sh — foto bukti M3 #9 (kritik #6 pemain 2026-10-14):
#   (a) arena = markas luar angkasa BERPENTENG (dinding+bastion PNG),
#   (b) logika build strategi: mode penempatan (hantu) sah & tidak sah + bilah
#       LETAKKAN/KONFIRMASI,
#   (c) tata letak basis awal (inti di tengah, turret menutup inti, produksi ring luar).
#
# Device class mobile-first ANDROID (1 CSS px = 1 dp, device px = CSS × dpr):
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp)
#   - 2340×1080 : CSS 780×360 @dpr 3 (19,5:9 xxhdpi)
# Usage: bash tools/vision/capture_m3_9_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/m3_9}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
rm -f "$OUT"/*.png.json
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 300000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Bukti M3 #9 (benteng + logika build) → $OUT"
# 00/01 markas berbenteng (kamera Command Mode, HUD aktif)
shot "/index.html?mode=camera&step=default" "$OUT/00_fortress_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 2000
shot "/index.html?mode=camera&step=default" "$OUT/01_fortress_2340x1080.png" 780 360 3 "QA:CAM:STEP_READY" 2000
# 02 seluruh benteng (zoom-out ke batas fit: village view)
shot "/index.html?mode=camera&step=far" "$OUT/02_fortress_zoomout_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 2000
# 03/04 mode penempatan: hantu sah (hijau) & tidak sah (merah, di luar plataran)
shot "/index.html?mode=place&step=valid" "$OUT/03_placement_valid_1280x720.png" 640 360 2 "QA:PLACE:READY" 1500
shot "/index.html?mode=place&step=invalid" "$OUT/04_placement_invalid_1280x720.png" 640 360 2 "QA:PLACE:READY" 1500
echo "==> selesai: $OUT"
