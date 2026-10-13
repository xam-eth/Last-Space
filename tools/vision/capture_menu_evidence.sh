#!/usr/bin/env bash
# capture_menu_evidence.sh — foto bukti MENU UTAMA M3 #4 (GAMEPLAY_FLOW Frame 3).
#
# Device class mobile-first ANDROID (standar, bukan asumsi: 1 CSS px = 1 dp,
# device px = CSS × dpr → HUD scale = dpr/2, design px = dp × 2):
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp, xhdpi) — scale 1,0
#   - 2340×1080 : CSS 780×360 @dpr 3 (19,5:9 xxhdpi)         — scale 1,5
#   - 1080×2340 : CSS 360×780 @dpr 3 (portrait)              — uji rotasi
#
# Satu state per proses (marker tunggu unik) karena setiap run WASM boot penuh.
# Usage: bash tools/vision/capture_menu_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/m3_main_menu}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 180000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Bukti menu utama M3 #4 → $OUT"
# 00/01 boot default: root = GAME yang boot ke fase MENU (fresh, tombol MULAI)
shot "/index.html" "$OUT/00_menu_boot_1280x720.png" 640 360 2 "QA:MENU:READY" 2500
shot "/index.html" "$OUT/01_menu_boot_2340x1080.png" 780 360 3 "QA:MENU:READY" 2500
# 02/03 sesi berjalan (save nyata ditulis showcase) → LANJUTKAN PERMAINAN
shot "/index.html?mode=menu&step=continue" "$OUT/02_menu_continue_1280x720.png" 640 360 2 "QA:MENU:CONTINUE_READY" 1800
shot "/index.html?mode=menu&step=continue" "$OUT/03_menu_continue_2340x1080.png" 780 360 3 "QA:MENU:CONTINUE_READY" 1800
# 04 LANJUTKAN dari save → LOAD nyata → kembali ke gameplay (HUD chrome muncul)
shot "/index.html?mode=menu&step=load" "$OUT/04_after_load_command_1280x720.png" 640 360 2 "QA:MENU:PLAY" 2500
# 05 PENGATURAN (jujur M3 #5 belum ada) — status di panel menu
shot "/index.html?mode=menu&step=settings" "$OUT/05_menu_settings_1280x720.png" 640 360 2 "QA:MENU:SETTINGS_READY" 1200
# 06 modal KREDIT (dialog ≤560dp)
shot "/index.html?mode=menu&step=credits" "$OUT/06_menu_credits_1280x720.png" 640 360 2 "QA:MENU:CREDITS_READY" 1200
# 07 jalur PAUSE MENU → MENU UTAMA (Frame 8 → Frame 3)
shot "/index.html?mode=menu&step=from_pause" "$OUT/07_from_pause_menu_1280x720.png" 640 360 2 "QA:MENU:FROM_PAUSE_READY" 1500
# 08 portrait (rotasi): panel tetap ukuran dp, anchor tengah-bawah
shot "/index.html?mode=menu&step=continue" "$OUT/08_menu_continue_portrait_1080x2340.png" 360 780 3 "QA:MENU:CONTINUE_READY" 1800
echo "==> selesai: $OUT"
