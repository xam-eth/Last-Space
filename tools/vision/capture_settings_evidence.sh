#!/usr/bin/env bash
# capture_settings_evidence.sh — foto bukti PANEL PENGATURAN M3 #5 (DEV_PLAN M3 #5).
#
# Device class mobile-first ANDROID (1 CSS px = 1 dp, device px = CSS × dpr,
# design px = dp × 2 saat HUD scale = dpr/2):
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp, xhdpi)  — scale 1,0
#   - 2340×1080 : CSS 780×360 @dpr 3 (19,5:9 xxhdpi)          — scale 1,5
#   - 1080×2340 : CSS 360×780 @dpr 3 (portrait, wajib diuji)  — dialog harus
#                 tetap ≤560dp & muat (kolom tunggal untuk baris kontrol)
# Satu state per proses (marker tunggu unik) karena tiap run WASM boot penuh.
# Usage: bash tools/vision/capture_settings_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/m35_settings}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 180000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Bukti panel PENGATURAN M3 #5 → $OUT"
# 00/01 panel dari menu utama (jalur produksi) — 16:9 xhdpi + 19,5:9 xxhdpi
shot "/index.html?mode=menu&step=settings" "$OUT/00_menu_settings_1280x720.png" 640 360 2 "QA:MENU:SETTINGS_READY" 2200
shot "/index.html?mode=settings" "$OUT/01_settings_panel_1280x720.png" 640 360 2 "QA:SETTINGS:DONE" 2500
shot "/index.html?mode=settings" "$OUT/02_settings_panel_2340x1080.png" 780 360 3 "QA:SETTINGS:DONE" 2500
# 03 portrait: dialog harus tetap muat & kolom tunggal (rotasi)
shot "/index.html?mode=menu&step=settings" "$OUT/03_menu_settings_portrait_1080x2340.png" 360 780 3 "QA:MENU:SETTINGS_READY" 2200
# 04 PENGATURAN dibuka dari PAUSE MENU (jalur ganti pesan "segera hadir")
shot "/index.html?mode=ui" "$OUT/04_pause_settings_1280x720.png" 640 360 2 "QA:UI:PAUSE_SETTINGS_OPEN" 2000
echo "==> selesai: $OUT"
