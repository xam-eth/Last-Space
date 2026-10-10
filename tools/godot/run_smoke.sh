#!/usr/bin/env bash
# run_smoke.sh — End-to-end verification of the Godot toolchain:
#   1. set up the Godot 4.7.2 web (WASM) runtime (setup_godot_web.sh)
#   2. pack the smoke-test project into a .pck (make_pck.py)
#   3. serve it and capture a screenshot with the vision tool (capture.mjs)
#
# Output: tools/godot/build/godot_smoke.png (+ .json report)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/tools/env.sh"

BUILD_DIR="$REPO_ROOT/tools/godot/build/smoke"
mkdir -p "$BUILD_DIR"

echo "==> [1/3] Godot web runtime setup"
bash "$REPO_ROOT/tools/godot/setup_godot_web.sh"

echo "==> [2/3] Packing smoke project into game.pck"
python3 "$REPO_ROOT/tools/godot/make_pck.py" \
	"$REPO_ROOT/tools/godot/smoke_project" "$BUILD_DIR/game.pck"

cp "$REPO_ROOT/tools/godot/smoke_project/index.html" "$BUILD_DIR/index.html"
cp "$GODOT_WEB_DIR/godot.js" "$GODOT_WEB_DIR/game.wasm" "$BUILD_DIR/"
# The web glue resolves the audio worklets as "<executable>.audio*.worklet.js"
cp "$GODOT_WEB_DIR/audio.worklet.js" "$BUILD_DIR/game.audio.worklet.js"
cp "$GODOT_WEB_DIR/audio.position.worklet.js" "$BUILD_DIR/game.audio.position.worklet.js"

echo "==> [3/3] Vision capture (headless Chromium)"
cd "$REPO_ROOT/tools/vision"
node capture.mjs /index.html "$REPO_ROOT/tools/godot/build/godot_smoke.png" 1280 720 \
	--serve "$BUILD_DIR" \
	--wait-for "LAST_SPACE_TOOLCHAIN_SMOKE" \
	--timeout 90000
