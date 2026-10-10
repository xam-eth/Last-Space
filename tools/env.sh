#!/usr/bin/env bash
# env.sh — shared environment for the Last-Space toolchain.
# Source this file before running the tools:
#   source tools/env.sh
#
# PORTABLE: default tools dir = $HOME/.last-space-tools (bisa di-override dengan
# GODOT_TOOLS_DIR). Tidak ada hardcode path mesin tertentu.
#
# Catatan: stub libs (LD_LIBRARY_PATH) hanya diperlukan di sandbox tanpa
# X11/GL/NSS. Di dev machine (yang punya libnss3, libXrender, dsb), stub tidak
# diperlukan dan env ini tidak mengganggu.
TOOLS_DIR="${GODOT_TOOLS_DIR:-$HOME/.last-space-tools}"
export LD_LIBRARY_PATH="$TOOLS_DIR/stublibs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GODOT_WEB_DIR="${GODOT_WEB_DIR:-$TOOLS_DIR/godot-web}"
export PATH="$TOOLS_DIR/godot-web:$PATH"
