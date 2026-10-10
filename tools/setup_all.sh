#!/usr/bin/env bash
# setup_all.sh — SETUP SATU PERINTAH untuk semua toolchain Last-Space,
# jalan di mesin apa pun (dev machine, CI, atau sandbox).
#
# Urutan: Blender (bpy) → vision tool (npm) → stub libs (opsional, hanya
# sandbox tanpa X11/GL/NSS) → Godot web runtime → verifikasi (tests + e2e).
#
# Usage: bash tools/setup_all.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> [1/4] Blender (bpy via pip)"
if ! pip3 install bpy==4.5.14 2>/dev/null; then
	pip3 install --break-system-packages bpy==4.5.14
fi

echo "==> [2/4] Vision tool (npm: @sparticuz/chromium + puppeteer-core)"
(cd "$REPO_ROOT/tools/vision" && npm install)

echo "==> [3/4] Stub libs (hanya diperlukan di sandbox tanpa X11/GL/NSS)"
if ! bash "$REPO_ROOT/tools/setup_stublibs.sh"; then
	echo "    (stub libs dilewati — kemungkinan mesin ini sudah punya library yang dibutuhkan)"
fi

echo "==> [4/4] Godot web runtime (4.7.2 WASM dari npm + source)"
bash "$REPO_ROOT/tools/godot/setup_godot_web.sh"

echo "==> Verifikasi: test suite + e2e playthrough"
bash "$REPO_ROOT/tools/godot/run_game_check.sh" all

echo "==> SETUP SELESAI — semua toolchain terverifikasi."
