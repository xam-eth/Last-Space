#!/usr/bin/env bash
# visual_benchmark.sh — BENCHMARK VISUAL BUILD: beberapa foto yang menunjukkan
# hasil akhir game secara visual (data nyata dari web build, bukan asumsi).
#
# Mengikuti instruksi:
# - QA_PLAN.md: vision check = screenshot valid (PNG, dimensi benar) + tidak
#   blank (cek piksel via Pillow); screenshot sebagai evidence tiap aspek.
# - ASSET_ACCEPTANCE_CRITERIA.md §5.3: tangkapan layar (vision evidence) dari
#   kamera gameplay aktual via tools/vision/capture.mjs.
# - ART_DIRECTION.md §1: 3 lapisan visual (base/command, armada, alien) harus
#   terbaca berbeda — foto benchmark mencakup ketiganya.
#
# Output: docs/visual_benchmark/*.png + report.json + VISUAL_BENCHMARK.md
# (dijalankan oleh verify_benchmark.py sesudah capture).
#
# Usage: bash tools/vision/visual_benchmark.sh   (butuh `source tools/env.sh`)
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$REPO_ROOT/docs/visual_benchmark"
mkdir -p "$OUT"
cd "$REPO_ROOT/tools/vision"

cap() { # out w h serve_dir waitfor settle timeout url
	node capture.mjs "$8" "$OUT/$1" "$2" "$3" --serve "$4" ${5:+--wait-for "$5"} \
		--wait-until domcontentloaded --settle "$6" --timeout "$7" >/dev/null 2>&1
	if [ ! -f "$OUT/$1" ]; then
		echo "ERROR: file tidak terbentuk: $1 (capture gagal)"
	else
		echo "capture: $1 ($2x$3)"
	fi
}

echo "==> [1/7] loading screen (root page)"
cap "01_loading_screen.png" 1920 1080 "$REPO_ROOT" "" 1500 60000 "/index.html"

echo "==> [2/7] command base — game utama (HUD + 3D base, kamera gameplay)"
cap "02_command_base.png" 1920 1080 "$REPO_ROOT/web" "QA:GAME:READY" 2500 90000 "/index.html"

echo "==> [3/7] armada — 6 interceptor formasi (model SHP-001)"
cap "03_fleet_formation.png" 1920 1080 "$REPO_ROOT/web" "QA:ASSET:READY" 2500 120000 "/index.html?mode=asset"

echo "==> [4/7] battle — defender vs attacker ALN-001 (alien hijau/ungu)"
cap "04_battle_vs_alien.png" 1920 1080 "$REPO_ROOT/web" "COMBAT:VISUAL_START" 900 120000 "/index.html?mode=asset"

echo "==> [5/7] stress — 42 kapal (12 SHP-001 + 30 ALN-001) + 8 turret"
cap "05_stress_42units.png" 1920 1080 "$REPO_ROOT/web" "QA:STRESS:COMPLETE" 2000 180000 "/index.html?mode=stress"

echo "==> [6/7] mobile landscape 16:9 (1920x1080)"
cap "06_mobile_1920x1080_16x9.png" 1920 1080 "$REPO_ROOT/web" "QA:GAME:READY" 2500 90000 "/index.html"

echo "==> [7/7] mobile landscape 19.5:9 (2340x1080) — full screen semua aspek"
cap "07_mobile_2340x1080_19.5x9.png" 2340 1080 "$REPO_ROOT/web" "QA:GAME:READY" 2500 90000 "/index.html"

echo "==> verifikasi piksel + report (QA_PLAN vision check)"
python3 "$REPO_ROOT/tools/vision/verify_benchmark.py" "$OUT"
