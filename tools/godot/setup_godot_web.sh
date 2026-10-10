#!/usr/bin/env bash
# setup_godot_web.sh — Prepare the Godot 4.7.2 engine runtime for headless
# vision testing in this sandbox.
#
# Why this exists: the official Godot editor binaries are GitHub *release
# assets* (blocked in this sandbox), and the Linux editor needs X11/GL
# libraries that are not installed here. The Godot **web (WASM)** build of the
# engine runs inside headless Chromium with SwiftShader — no X11 needed — and
# gives us real engine rendering + screenshots for vision verification.
#
# Sources (all reachable hosts only):
#   - Engine WASM build : npm package @ringozz/godot-web-wasm32 (official
#                         Godot 4.7.2 web template build, shipped inside the
#                         npm tarball → registry.npmjs.org)
#   - Engine shell JS   : Godot source tree, platform/web/js/engine/*.js
#                         (the `Engine` class used by the official web shell)
#                         → codeload.github.com
#
# Output: $GODOT_WEB_DIR (default /home/user/tools/godot-web) containing:
#   godot.js                  Emscripten glue + Engine shell class (bundled)
#   game.wasm                 Godot 4.7.2 web (wasm32, nothreads) engine
#   audio.worklet.js          Godot web audio worklets
#   audio.position.worklet.js
set -euo pipefail

GODOT_TAG="4.7.2-stable"
RINGOZZ_PKG="@ringozz/godot-web-wasm32@4.7.2-643" # official 4.7.2 web build

TOOLS_DIR="${GODOT_TOOLS_DIR:-/home/user/tools}"
ENGINE_DIR="${GODOT_WEB_DIR:-$TOOLS_DIR/godot-web}"
SRC_DIR="$TOOLS_DIR/godot-src"

mkdir -p "$ENGINE_DIR" "$SRC_DIR"

# --- 1. Godot source tree (only the web shell JS is needed) -----------------
if [ ! -f "$SRC_DIR/platform/web/js/engine/engine.js" ]; then
	echo "==> Downloading Godot $GODOT_TAG source (web shell JS)"
	curl -sL "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/$GODOT_TAG" \
		-o "$TOOLS_DIR/godot-src.tar.gz"
	tar xzf "$TOOLS_DIR/godot-src.tar.gz" -C "$SRC_DIR" --strip-components=1
fi

# --- 2. Engine WASM build from npm ------------------------------------------
if [ ! -f "$ENGINE_DIR/game.wasm" ]; then
	echo "==> Installing $RINGOZZ_PKG from npm"
	NPM_DIR="$ENGINE_DIR/npm-pkg"
	mkdir -p "$NPM_DIR"
	cat > "$NPM_DIR/package.json" <<'EOF'
{ "name": "godot-web-engine", "private": true, "version": "0.0.0" }
EOF
	(cd "$NPM_DIR" && npm install "$RINGOZZ_PKG" --no-audit --no-fund)

	PKG="$NPM_DIR/node_modules/@ringozz/godot-web-wasm32/gen"
	echo "==> Extracting engine files"
	cp "$PKG/godot.web.template_release.wasm32.nothreads.wasm" "$ENGINE_DIR/game.wasm"
	cp "$PKG/audio.worklet.js" "$ENGINE_DIR/audio.worklet.js"
	cp "$PKG/audio.position.worklet.js" "$ENGINE_DIR/audio.position.worklet.js"

	echo "==> Bundling godot.js (Emscripten glue + Engine shell class)"
	# The glue is an ES module whose default export is the `Godot` module
	# factory. The official web shell additionally needs the `Engine` class
	# (platform/web/js/engine/*.js from the Godot source), which expects the
	# `Godot` factory in scope — so we concatenate everything into one module.
	sed 's/export default Godot;[[:space:]]*$//' \
		"$PKG/godot.web.template_release.wasm32.nothreads.js" > "$ENGINE_DIR/godot.js"
	cat "$SRC_DIR/platform/web/js/engine/preloader.js" >> "$ENGINE_DIR/godot.js"
	cat "$SRC_DIR/platform/web/js/engine/config.js"      >> "$ENGINE_DIR/godot.js"
	cat "$SRC_DIR/platform/web/js/engine/features.js"    >> "$ENGINE_DIR/godot.js"
	cat "$SRC_DIR/platform/web/js/engine/engine.js"      >> "$ENGINE_DIR/godot.js"
	echo "export default Godot;" >> "$ENGINE_DIR/godot.js"
fi

echo "==> Godot web runtime ready:"
ls -la "$ENGINE_DIR" | grep -vE "^total|^d.*\s\.\.?$"
