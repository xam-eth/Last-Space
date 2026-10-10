#!/usr/bin/env bash
# env.sh — shared environment for the Last-Space toolchain in this sandbox.
# Source this file before running the tools:
#   source tools/env.sh
#
# The sandbox has no X11/GL/NSS system libraries (and no package manager
# access), so we provide minimal stub shared libraries for the GUI-only
# symbols that Blender (bpy) and Chromium (@sparticuz/chromium) link against
# but never call in headless/background operation. See TOOLCHAIN.md.
TOOLS_DIR="${GODOT_TOOLS_DIR:-/home/user/tools}"
export LD_LIBRARY_PATH="$TOOLS_DIR/stublibs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GODOT_WEB_DIR="${GODOT_WEB_DIR:-$TOOLS_DIR/godot-web}"
export PATH="$TOOLS_DIR/godot-web:$PATH"
