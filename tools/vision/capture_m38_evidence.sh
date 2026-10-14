#!/usr/bin/env bash
# capture_m38_evidence.sh — foto bukti M3 #8 (kritik #5 pemain 2026-10-14):
#   (a) card katalog 56dp (dari 68dp) — 4 device class (2 ponsel + tablet + portrait),
#   (b) kamera v2 dinamis: zoom dekat (deklutter label) + pan;
#   (c) alur klik nyata (semua tab + kartu + drag kiri pan) untuk AC5.
#
# Device class mobile-first ANDROID (1 CSS px = 1 dp, device px = CSS × dpr):
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp) — scale 1,0
#   - 2340×1080 : CSS 780×360 @dpr 3 (19,5:9 xxhdpi)   — scale 1,5
#   - 1080×2340 : CSS 360×780 @dpr 3 (portrait, wajib diuji)
# Usage: bash tools/vision/capture_m38_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/m3_8_cards_camera}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
# Jangan pakai .json lama dari capture sebelumnya (aturan QA: hapus dulu).
rm -f "$OUT"/*.png.json
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 240000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Bukti M3 #8 (card 56dp + kamera v2) → $OUT"
# 00/01/02 menu BANGUN dengan card 56dp (ikon SVG, tanpa label teks)
shot "/index.html?mode=ui" "$OUT/00_cards_56dp_1280x720.png" 640 360 2 "QA:UI:MENU_DONE" 1800
shot "/index.html?mode=ui" "$OUT/01_cards_56dp_2340x1080.png" 780 360 3 "QA:UI:MENU_DONE" 1800
## Portrait 360dp: shell menampilkan PROMPT ROTASI (keputusan pemain) — foto ini
## membuktikan prompt nyata + audit internal modal tetap jalan (marker narrow).
shot "/index.html?mode=ui" "$OUT/02_rotate_prompt_portrait_1080x2340.png" 360 780 3 "QA:ROTATE:PROMPT" 1800
## Tablet 4:3 (1024×768 dp): aspek berbeda dari ponsel — modal tidak boleh melimpah.
shot "/index.html?mode=ui" "$OUT/06_cards_56dp_tablet4x3_2048x1536.png" 1024 768 2 "QA:UI:MENU_DONE" 1800
# 03/04 kamera: zoom dekat (deklutter menyembunyikan label) + pan
shot "/index.html?mode=camera&step=close" "$OUT/03_camera_close_1280x720.png" 640 360 2 "QA:CAM:STEP_READY" 1500
shot "/index.html?mode=camera&step=pan" "$OUT/04_camera_pan_2340x1080.png" 780 360 3 "QA:CAM:STEP_READY" 1500
# 05 alur klik nyata (semua tab + kartu + drag kiri pan) — AC5
shot "/index.html?mode=input" "$OUT/05_input_flow_1280x720.png" 640 360 2 "QA:INPUT:DONE" 1500
echo "==> selesai: $OUT"
