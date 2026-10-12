#!/usr/bin/env bash
# run_game_check.sh — pack project game dan jalankan verifikasi otomatis di
# headless Chromium (QA_PLAN.md gates):
#   tests : test suite (data + unit + integration) — marker TESTS:DONE
#   e2e   : playthrough end-to-end — marker QA:LOOP:COMPLETE
#   game  : smoke build bisa dimainkan — marker QA:GAME:READY
#   asset : pilot asset SHP-001 di scene perwakilan — marker QA:ASSET:READY
#   sim   : simulasi ekonomi headless ratusan hari — marker QA:SIM:COMPLETE
#   stress: pengukuran performa stress scene — marker QA:STRESS:COMPLETE
#   ui    : showcase UI M3 (quest panel + selected + build + ship + pause menu)
#           — marker QA:UI:MENU_DONE (DEV_PLAN M3 #1)
#
# Usage: bash tools/godot/run_game_check.sh [all|tests|e2e|game|asset|sim|stress|ui|perf]
# Exit code = jumlah suite yang FAIL (0 = semua PASS).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/tools/env.sh"

# --- pre-flight: pastikan runtime & vision tool sudah siap (pesan jelas) ---
if [ ! -f "$GODOT_WEB_DIR/game.wasm" ] || [ ! -f "$GODOT_WEB_DIR/godot.js" ]; then
	echo "ERROR: Godot web runtime belum ter-setup (tidak ada $GODOT_WEB_DIR/game.wasm)" >&2
	echo "Jalankan dulu: bash tools/godot/setup_godot_web.sh" >&2
	echo "Atau setup semua sekaligus: bash tools/setup_all.sh" >&2
	exit 1
fi
if [ ! -d "$REPO_ROOT/tools/vision/node_modules/@sparticuz/chromium" ]; then
	echo "ERROR: vision tool belum ter-install (tools/vision/node_modules)" >&2
	echo "Jalankan dulu: cd tools/vision && npm install" >&2
	echo "Atau setup semua sekaligus: bash tools/setup_all.sh" >&2
	exit 1
fi


BUILD="$REPO_ROOT/tools/godot/build/game"
mkdir -p "$BUILD"

echo "==> Generating global script class cache (editor-less class_name resolution)"
python3 "$REPO_ROOT/tools/godot/make_script_class_cache.py" "$REPO_ROOT/game"

echo "==> Packing game project (game/ -> game.pck)"
python3 "$REPO_ROOT/tools/godot/make_pck.py" "$REPO_ROOT/game" "$BUILD/game.pck"

cp "$REPO_ROOT/game/shell/index.html" "$BUILD/index.html"
cp "$GODOT_WEB_DIR/godot.js" "$GODOT_WEB_DIR/game.wasm" "$BUILD/"
cp "$GODOT_WEB_DIR/audio.worklet.js" "$BUILD/game.audio.worklet.js"
cp "$GODOT_WEB_DIR/audio.position.worklet.js" "$BUILD/game.audio.position.worklet.js"

# --- sinkronkan build ke web/ (build WebGL yang di-COMMIT — untuk preview
# tanpa install tools apa pun; game jalan di WebGL, bukan di tools) ---
WEB_DIR="$REPO_ROOT/web"
mkdir -p "$WEB_DIR"
cp "$BUILD/index.html" "$WEB_DIR/index.html"
cp "$BUILD/game.pck" "$WEB_DIR/game.pck"
cp "$GODOT_WEB_DIR/godot.js" "$GODOT_WEB_DIR/game.wasm" "$WEB_DIR/"
cp "$GODOT_WEB_DIR/audio.worklet.js" "$WEB_DIR/game.audio.worklet.js"
cp "$GODOT_WEB_DIR/audio.position.worklet.js" "$WEB_DIR/game.audio.position.worklet.js"
echo "==> web/ (preview build, di-commit) tersinkronkan"

MODE="${1:-all}"
FAILURES=0

run_capture() { # url out waitfor timeout [throttle]
	cd "$REPO_ROOT/tools/vision"
	# device class mobile-first: CSS 640×360 (= 360dp baseline 16:9) @dpr 2 →
	# output 1280×720 device px; HUD scale = dpr/2 = 1,0 (1 design px = 0,5dp).
	node capture.mjs "$1" "$2" 640 360 --dpr 2 --serve "$BUILD" --wait-for "$3" --timeout "$4" --wait-until domcontentloaded --settle 2000 ${5:+--throttle "$5"}
}

check_report() { # png.json — FAIL jika ada TEST:FAIL / pageErrors / TESTS:DONE failed>0
	python3 - "$1" <<'PYEOF'
import json, sys
report = json.load(open(sys.argv[1]))
logs = report.get("consoleLogs", [])
fails = [l for l in logs if "TEST:FAIL" in l]
skips = [l for l in logs if "TEST:SKIP" in l]
done = [l for l in logs if "TESTS:DONE" in l]
errors = report.get("pageErrors", [])
ok = not fails and not errors and report.get("waitForMatched") is True
if done and "failed=0" not in done[-1]:
	ok = False
print("REPORT %s: fails=%d skips=%d pageErrors=%d | %s -> %s" % (
	sys.argv[1].split('/')[-1], len(fails), len(skips), len(errors),
	done[-1] if done else "no TESTS:DONE", "PASS" if ok else "FAIL"))
for f in fails[:10]:
	print("  ", f)
for e in errors[:10]:
	print("  PAGEERROR:", e)
sys.exit(0 if ok else 1)
PYEOF
}

if [ "$MODE" = "all" ] || [ "$MODE" = "tests" ]; then
	echo "==> [tests] data + unit + integration suite"
	run_capture "/index.html?mode=tests" "$REPO_ROOT/tools/godot/build/game_tests.png" "TESTS:DONE" 120000
	check_report "$REPO_ROOT/tools/godot/build/game_tests.png.json" || FAILURES=$((FAILURES+1))
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "e2e" ]; then
	echo "==> [e2e] full gameplay loop playthrough"
	run_capture "/index.html?mode=e2e" "$REPO_ROOT/tools/godot/build/game_e2e.png" "QA:LOOP:COMPLETE" 180000
	check_report "$REPO_ROOT/tools/godot/build/game_e2e.png.json" || FAILURES=$((FAILURES+1))
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "game" ]; then
	echo "==> [game] playable build smoke"
	run_capture "/index.html" "$REPO_ROOT/tools/godot/build/game_play.png" "QA:GAME:READY" 60000
	check_report "$REPO_ROOT/tools/godot/build/game_play.png.json" || FAILURES=$((FAILURES+1))
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "asset" ]; then
	echo "==> [asset] pilot asset SHP-001 di scene perwakilan (base game nyata)"
	run_capture "/index.html?mode=asset" "$REPO_ROOT/tools/godot/build/game_asset.png" "QA:ASSET:READY" 120000
	check_report "$REPO_ROOT/tools/godot/build/game_asset.png.json" || FAILURES=$((FAILURES+1))
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "sim" ]; then
	echo "==> [sim] simulasi ekonomi headless 200 hari (DEV_PLAN M2 #2)"
	run_capture "/index.html?mode=sim" "$REPO_ROOT/tools/godot/build/game_sim.png" "QA:SIM:COMPLETE" 300000
	check_report "$REPO_ROOT/tools/godot/build/game_sim.png.json" || FAILURES=$((FAILURES+1))
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "stress" ]; then
	echo "==> [stress] pengukuran performa stress scene 42 kapal + 8 turret (DEV_PLAN M2 #3)"
	run_capture "/index.html?mode=stress" "$REPO_ROOT/tools/godot/build/game_stress.png" "QA:STRESS:COMPLETE" 180000
	check_report "$REPO_ROOT/tools/godot/build/game_stress.png.json" || FAILURES=$((FAILURES+1))
	# Memory (JS heap) diukur via page.metrics() di capture.mjs — data nyata Chromium.
	python3 - "$REPO_ROOT/tools/godot/build/game_stress.png.json" <<'INNER_PY' || FAILURES=$((FAILURES+1))
import json, sys
r = json.load(open(sys.argv[1]))
heap = r.get("metrics", {}).get("JSHeapUsedSize", 0)
ok = heap > 0
print("STRESS MEMORY: JSHeapUsedSize=%.1fMB -> %s" % (heap / 1048576.0, "PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
INNER_PY
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "ui" ]; then
	echo "==> [ui] showcase UI M3: quest panel + building selected + build + ship + pause menu (DEV_PLAN M3 #1/#2/#3)"
	run_capture "/index.html?mode=ui" "$REPO_ROOT/tools/godot/build/game_ui.png" "QA:UI:PAUSE_DONE" 120000
	check_report "$REPO_ROOT/tools/godot/build/game_ui.png.json" || FAILURES=$((FAILURES+1))
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "perf" ]; then
	echo "==> [perf] stress scene di emulated device class (CPU throttle 1x/4x/6x) — data nyata untuk keputusan device class (DEV_PLAN M2 #5)"
	for T in 1 4 6; do
		run_capture "/index.html?mode=stress" "$REPO_ROOT/tools/godot/build/game_perf_t${T}.png" "QA:STRESS:COMPLETE" 180000 "$T"
		check_report "$REPO_ROOT/tools/godot/build/game_perf_t${T}.png.json" || FAILURES=$((FAILURES+1))
	done
	python3 - "$REPO_ROOT/tools/godot/build" <<'PERF_PY'
import json, sys, os, re
d = sys.argv[1]
print("PERF PER DEVICE CLASS (emulated CPU throttle, SwiftShader software GL):")
for t, label in [(1, "1x  (baseline sandbox)"), (4, "4x  (~mid-tier mobile)"), (6, "6x  (~low-end budget)")]:
    r = json.load(open(os.path.join(d, "game_perf_t%d.png.json" % t)))
    logs = r.get("consoleLogs", [])
    met = [l for l in logs if "QA:STRESS:METRICS" in l]
    heap = r.get("metrics", {}).get("JSHeapUsedSize", 0) / 1048576.0
    if met:
        m = met[-1]
        def g(k):
            mm = re.search(k + r"=([0-9.]+)", m)
            return mm.group(1) if mm else "?"
        print("  throttle %s | fps_avg=%s fps_min=%s frame_ms_avg=%s frame_ms_max=%s heap=%.1fMB" % (
            label, g("fps_avg"), g("fps_min"), g("frame_ms_avg"), g("frame_ms_max"), heap))
PERF_PY
fi

echo "==> run_game_check: $FAILURES suite FAIL"
exit $FAILURES
