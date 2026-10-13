#!/usr/bin/env bash
# capture_camera_evidence.sh — foto bukti KAMERA Command Mode M3 #6
# (zoom & pan: tombol HUD eksplisit + gesture).
#
# Device class mobile-first ANDROID (1 CSS px = 1 dp, device px = CSS × dpr):
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp xhdpi)
#   - 1080×2340 : CSS 360×780 @dpr 3 (portrait — kontrol zoom harus tetap di
#                 tepi kanan & tidak menutupi arena)
# Satu state per proses (marker tunggu unik) karena tiap run WASM boot penuh.
# Usage: bash tools/vision/capture_camera_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/m3_6_camera}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 180000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Bukti kamera M3 #6 → $OUT"
shot "/index.html?mode=camera&step=default" "$OUT/00_zoom_default_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 2000
shot "/index.html?mode=camera&step=close" "$OUT/01_zoom_close_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 2000
shot "/index.html?mode=camera&step=far" "$OUT/02_zoom_far_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 2000
shot "/index.html?mode=camera&step=pan" "$OUT/03_pan_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 2000
shot "/index.html?mode=camera&step=close" "$OUT/04_zoom_close_portrait_1080x2340.png" 360 780 3 "QA:CAM:STEP_READY" 2000
echo "==> selesai: $OUT"
