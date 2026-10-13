#!/usr/bin/env bash
# capture_m37_evidence.sh — foto bukti M3 #7 (koreksi pemain 2026-10-13):
#   (a) elemen arena = FOTO PNG ber-chroma-key (planet/bulan/nebula/stasiun),
#   (b) ikon = berkas SVG asli,
#   (c) card katalog lebih kecil (68dp) + kartu aksi 64dp,
#   (d) interaksi klik nyata (menu BANGUN/ARMADA/zoom/pause).
#
# Device class mobile-first ANDROID (1 CSS px = 1 dp, device px = CSS × dpr):
#   - 1280×720  : CSS 640×360 @dpr 2 (baseline 360dp) — scale 1,0
#   - 2340×1080 : CSS 780×360 @dpr 3 (19,5:9 xxhdpi)   — scale 1,5
#   - 1080×2340 : CSS 360×780 @dpr 3 (portrait, wajib diuji)
# Usage: bash tools/vision/capture_m37_evidence.sh [outdir]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/tools/env.sh"
OUT="${1:-$REPO_ROOT/docs/m37_3d_png}"
BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$OUT"
cd "$REPO_ROOT/tools/vision"

shot() { # url out cssw cssh dpr waitfor settle
	node capture.mjs "$1" "$2" "$3" "$4" --dpr "$5" --serve "$BUILD" \
		--wait-for "$6" --timeout 180000 --wait-until domcontentloaded --settle "$7" >/dev/null
	echo "  ok $(basename "$2") ($(python3 -c "
import json;d=json.load(open('$2.json'));print('%dx%d dpr %s' % (d['png']['width'], d['png']['height'], d['devicePixelRatio']))"))"
}

echo "==> Bukti M3 #7 (arena PNG + ikon SVG + card lebih kecil) → $OUT"
# 00/01 arena: elemen PNG (planet gas bercincin, bulan, nebula, stasiun) — boot
# ke fase MENU dengan kamera idle supaya seluruh latar terlihat.
shot "/index.html" "$OUT/00_arena_png_1280x720.png" 640 360 2 "QA:MENU:READY" 2500
shot "/index.html" "$OUT/01_arena_png_2340x1080.png" 780 360 3 "QA:MENU:READY" 2500
# 02 menu BANGUN dengan card 68dp (ikon SVG terasterisasi)
shot "/index.html?mode=ui" "$OUT/02_build_cards_1280x720.png" 640 360 2 "QA:UI:MENU_DONE" 1500
# 03 gameplay penuh (HUD + arena + zoom cluster)
shot "/index.html?mode=ui" "$OUT/03_hud_arena_2340x1080.png" 780 360 3 "QA:UI:MENU_DONE" 1500
# 04 interaksi klik nyata selesai (menu ARMADA pernah dibuka, toast alasan tampil)
shot "/index.html?mode=input" "$OUT/04_input_flow_1280x720.png" 640 360 2 "QA:INPUT:DONE" 1500
# 05 portrait (rotasi): card & HUD tetap ukuran dp
shot "/index.html?mode=ui" "$OUT/05_build_cards_portrait_1080x2340.png" 360 780 3 "QA:UI:MENU_DONE" 1500
echo "==> selesai: $OUT"
