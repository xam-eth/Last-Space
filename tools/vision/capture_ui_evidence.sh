#!/usr/bin/env bash
# capture_ui_evidence.sh — evidence foto UI M3/M3.6 (reproducible, device class
# mobile-first ANDROID — standar, bukan asumsi):
#   1 CSS px = 1 dp (Android density-independent), device px = CSS × dpr.
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp, xhdpi) — HUD scale 1,0
#   - 2340×1080 : CSS 780×360 @dpr 3 (19.5:9 xxhdpi)          — HUD scale 1,5
# Output ke docs/ui_m3_build_menu/ (nama file dipertahankan dari M3 #1).
#
# Usage: bash tools/vision/capture_ui_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/ui_m3_build_menu}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 180000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Evidence UI (1280x720 = 640x360 CSS @dpr2; 2340x1080 = 780x360 CSS @dpr3)"
# 00 baseline: game biasa tanpa selection (mode=game)
shot "/index.html" "$OUT/00_baseline_1280x720.png" 640 360 2 "QA:GAME:READY" 2500
# 01 selection: jendela 1,2 dtk sebelum build menu terbuka → settle 800
shot "/index.html?mode=ui" "$OUT/01_command_selected_1280x720.png" 640 360 2 "QA:UI:SELECT_DONE" 800
# 02 build menu: jendela 0,8 dtk sebelum ship menu → settle 500
shot "/index.html?mode=ui" "$OUT/02_build_menu_1280x720.png" 640 360 2 "QA:UI:MENU_DONE" 500
shot "/index.html?mode=ui" "$OUT/03_command_selected_2340x1080.png" 780 360 3 "QA:UI:SELECT_DONE" 800
shot "/index.html?mode=ui" "$OUT/04_build_menu_2340x1080.png" 780 360 3 "QA:UI:MENU_DONE" 500
shot "/index.html?mode=ui" "$OUT/05_ship_menu_1280x720.png" 640 360 2 "QA:UI:SHIP_DONE" 500
shot "/index.html?mode=ui" "$OUT/06_ship_menu_2340x1080.png" 780 360 3 "QA:UI:SHIP_DONE" 500
shot "/index.html?mode=ui" "$OUT/07_pause_menu_1280x720.png" 640 360 2 "QA:UI:PAUSE_OPEN" 300
shot "/index.html?mode=ui" "$OUT/08_pause_menu_2340x1080.png" 780 360 3 "QA:UI:PAUSE_OPEN" 300
echo "==> selesai: $OUT"
