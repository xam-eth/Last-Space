#!/usr/bin/env bash
# run_game_check.sh — pack project game dan jalankan verifikasi otomatis di
# headless Chromium (QA_PLAN.md gates):
#   tests : test suite (data + unit + integration) — marker TESTS:DONE
#   e2e   : playthrough end-to-end — marker QA:LOOP:COMPLETE
#   game  : smoke build bisa dimainkan — marker QA:GAME:READY
#
# Usage: bash tools/godot/run_game_check.sh [all|tests|e2e|game]
# Exit code = jumlah suite yang FAIL (0 = semua PASS).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/tools/env.sh"

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

MODE="${1:-all}"
FAILURES=0

run_capture() { # url out waitfor timeout
	cd "$REPO_ROOT/tools/vision"
	node capture.mjs "$1" "$2" 1280 720 --serve "$BUILD" --wait-for "$3" --timeout "$4"
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

if [ "$MODE" = "game" ]; then
	echo "==> [game] playable build smoke"
	run_capture "/index.html" "$REPO_ROOT/tools/godot/build/game_play.png" "QA:GAME:READY" 60000
	check_report "$REPO_ROOT/tools/godot/build/game_play.png.json" || FAILURES=$((FAILURES+1))
fi

echo "==> run_game_check: $FAILURES suite FAIL"
exit $FAILURES
