#!/usr/bin/env bash
# setup_stublibs.sh — Regenerate the stub shared libraries needed to run
# Blender (bpy) and Chromium (@sparticuz/chromium) in this headless sandbox.
#
# Why: the sandbox has no X11/GL/NSS system libraries and no package-manager
# access. bpy and Chromium link against a handful of GUI/crypto libs whose
# symbols are NEVER called during headless/background operation, so we provide
# minimal stub .so files exporting exactly the symbols the dynamic loader
# needs. This is a sandbox-only workaround — on a normal dev machine, install
# the real libraries (apt install libxrender1 libgl1 libnss3 ...) instead.
#
# The script is fully automatic and idempotent:
#   1. find every missing SONAME via `ldd`
#   2. create empty stubs → collect still-undefined symbols via `ldd -r`
#      (Python C-API `Py*` symbols are excluded: the python interpreter
#      provides them at runtime)
#   3. regenerate the stubs exporting those symbols
#   4. verify (import bpy, launch chromium headless)
#
# Prerequisites: bpy installed (pip), tools/vision npm packages installed.
set -euo pipefail

STUB_DIR="${STUBLIBS_DIR:-${GODOT_TOOLS_DIR:-$HOME/.last-space-tools}/stublibs}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BPY_SITE="$(python3 -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")/bpy"
VISION_DIR="$REPO_ROOT/tools/vision"

if [ ! -d "$BPY_SITE" ]; then
	echo "ERROR: bpy not found at $BPY_SITE — run: pip3 install bpy==4.5.14" >&2
	exit 1
fi
if [ ! -d "$VISION_DIR/node_modules/@sparticuz/chromium" ]; then
	echo "ERROR: @sparticuz/chromium not installed — run: cd tools/vision && npm install" >&2
	exit 1
fi

mkdir -p "$STUB_DIR"
rm -f "$STUB_DIR"/*.so "$STUB_DIR"/*.so.* 2>/dev/null || true

make_empty_stub() { # soname
	echo 'void __stub_placeholder(void){}' | gcc -shared -x c - -Wl,-soname,"$1" -o "$STUB_DIR/$1"
}

make_stub() { # soname symbols-file
	{
		echo '/* auto-generated stub library — sandbox headless workaround */'
		while IFS= read -r s; do
			[ -n "$s" ] && echo "void $s(void){}"
		done < "$2"
	} | gcc -shared -fPIC -x c - -Wl,-soname,"$1" -o "$STUB_DIR/$1"
}

collect_missing() { # so-files...
	local so
	for so in "$@"; do
		ldd "$so" 2>/dev/null | grep "not found" | awk '{print $1}' || true
	done | sort -u
}

collect_undefined() { # so-files... (with stub dir on LD_LIBRARY_PATH)
	# Simbol berversi tampil sebagai "NAME, version V_x.y\t(path)" — ambil token
	# nama saja (field pertama, dipisah spasi/tab oleh awk), lalu buang karakter
	# non-kata. Jangan andalkan \t di dalam bracket expression sed.
	local so
	for so in "$@"; do
		LD_LIBRARY_PATH="$STUB_DIR" ldd -r "$so" 2>&1 \
			| grep "undefined symbol" \
			| sed 's/.*undefined symbol: //' \
			| awk '{print $1}' \
			| sed 's/[^A-Za-z0-9_]//g' || true
	done | grep -v '^$' | sort -u || true
}

echo "==> [1/2] Blender (bpy) stub libraries"
# Scan hanya runtime closure bpy: __init__.so + lib bundled (lib/).
# Modul python di site-packages (MaterialX/openvdb) sengaja TIDAK discan:
# dependensinya resolve via RPATH interpreter saat runtime, dan ldd standalone
# akan melaporkan "not found" palsu.
mapfile -t BPY_SOS < <( { ls "$BPY_SITE/__init__.so"; ls "$BPY_SITE"/lib/*.so*; } 2>/dev/null | sort -u )
echo "    scanning ${#BPY_SOS[@]} shared objects (bpy runtime closure)"
MISSING_BPY="$(collect_missing "${BPY_SOS[@]}")"
if [ -z "$MISSING_BPY" ]; then
	echo "    nothing missing (already satisfied?)"
else
	for soname in $MISSING_BPY; do make_empty_stub "$soname"; done
	collect_undefined "${BPY_SOS[@]}" | grep -vE '^_?Py' > "$STUB_DIR/.bpy_syms.txt" || true
	N_SYMS="$(wc -l < "$STUB_DIR/.bpy_syms.txt")"
	for soname in $MISSING_BPY; do make_stub "$soname" "$STUB_DIR/.bpy_syms.txt"; done
	echo "    stubbed: $(echo $MISSING_BPY | tr '\n' ' ')( dengan $N_SYMS simbol)"
fi

echo "==> [2/2] Chromium (@sparticuz/chromium) stub libraries"
CHROME_BIN="$(cd "$VISION_DIR" && node -e "import('@sparticuz/chromium').then(m=>m.default.executablePath()).then(p=>{console.log(p)}).catch(e=>{console.error(String(e));process.exit(1)})")"
echo "    chromium binary: $CHROME_BIN"
MISSING_CHROME="$(collect_missing "$CHROME_BIN")"
if [ -z "$MISSING_CHROME" ]; then
	echo "    nothing missing (already satisfied?)"
else
	for soname in $MISSING_CHROME; do make_empty_stub "$soname"; done
	collect_undefined "$CHROME_BIN" > "$STUB_DIR/.chrome_syms.txt" || true
	N_SYMS="$(wc -l < "$STUB_DIR/.chrome_syms.txt")"
	for soname in $MISSING_CHROME; do make_stub "$soname" "$STUB_DIR/.chrome_syms.txt"; done
	echo "    stubbed: $(echo $MISSING_CHROME | tr '\n' ' ')( dengan $N_SYMS simbol)"
fi

rm -f "$STUB_DIR/.bpy_syms.txt" "$STUB_DIR/.chrome_syms.txt"

echo "==> Verifying stubs"
export LD_LIBRARY_PATH="$STUB_DIR"
python3 -c "import bpy; print('    bpy import OK:', bpy.app.version_string)"
(cd "$VISION_DIR" && node capture.mjs fixtures/smoke.html "$STUB_DIR/../stublibs_check.png" 320 180 >/dev/null 2>&1 \
	&& echo "    chromium headless launch OK (screenshot captured)" \
	|| { echo "    ERROR: chromium launch failed" >&2; exit 1; })
rm -f "$STUB_DIR/../stublibs_check.png" "$STUB_DIR/../stublibs_check.png.json"

echo "==> Stub libraries ready: $STUB_DIR"
ls "$STUB_DIR"
