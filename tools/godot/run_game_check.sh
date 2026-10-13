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
#   settings: panel PENGATURAN M3 #5 (audio/tampilan/ukuran UI/bahasa) +
#           persistensi user://settings.json — marker QA:SETTINGS:DONE
#   menu  : menu utama M3 #4 (base idle + panel: MULAI / LANJUTKAN / PENGATURAN
#           / KREDIT / LOAD nyata) — marker QA:MENU:SHOWCASE:DONE
#
# Usage: bash tools/godot/run_game_check.sh [all|tests|e2e|game|asset|sim|stress|ui|menu|settings|perf]
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
	# Gate tambahan: scene & HUD HARUS benar-benar terbangun (script error di
	# base_scene/hud sebelumnya lolos karena hanya marker boot yang dicek).
	if ! grep -q "QA:SCENE:ENV" "$REPO_ROOT/tools/godot/build/game_play.png.json"; then
		echo "REPORT game_play.png.json: FAIL — QA:SCENE:ENV tidak ada (base_scene gagal dibangun)" >&2
		FAILURES=$((FAILURES+1))
	elif ! grep -q "QA:HUD:LAYOUT" "$REPO_ROOT/tools/godot/build/game_play.png.json"; then
		echo "REPORT game_play.png.json: FAIL — QA:HUD:LAYOUT tidak ada (HUD gagal dibangun)" >&2
		FAILURES=$((FAILURES+1))
	else
		check_report "$REPO_ROOT/tools/godot/build/game_play.png.json" || FAILURES=$((FAILURES+1))
	fi
	# M3 #4: root default = game yang boot ke MENU (base idle) — bukan langsung
	# COMMAND. Dibuktikan dari marker nyata: panel menu muncul, chrome HUD
	# disembunyikan, dan panel dihitung dari konten (fit) — bukan teks statis.
	python3 - "$REPO_ROOT/tools/godot/build/game_play.png.json" <<'MENU_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
checks = {
    "QA:MENU:READY (menu terbuka di boot)": has(r"QA:MENU:READY .*primary=MULAI"),
    "QA:MENU:READY tanpa save (fresh)": has(r"QA:MENU:READY .*has_save=false"),
    "QA:MENU:FIT fit=ok": has(r"QA:MENU:FIT .*fit=ok"),
    "QA:MENU:OVERLAP count=0 (anti-tumpuk)": has(r"QA:MENU:OVERLAP .*count=0"),
    "QA:MENU:DUMP 56dp/48dp": has(r"QA:MENU:DUMP .*primary_dp=56") and has(r"QA:MENU:DUMP .*secondary_dp=48"),
    "waktu beku di menu (speed=0)": has(r"QA:MENU:SCENE .*state=boot_menu .*speed=0"),
    "chrome HUD disembunyikan di menu (6 zona)": all(
        has(r"%s\[[^\]]*\]_hidden" % z) for z in
        ["TopBar", "QuestPanel", "InfoPanel", "SelectionPanel", "ActionGrid", "Toast"]),
    "label dunia disembunyikan di menu (3D)": has(
        r"QA:SCENE:LABEL_MENU state=hidden total=\d+"),
    "fase MENU": has(r"QA:GAME:PHASE phase=MENU"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  MENU CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT game_play.png.json (M3 #4 menu): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
MENU_PY
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "menu" ]; then
	echo "==> [menu] menu utama M3 #4: base idle + panel (MULAI/LANJUTKAN/PENGATURAN/KREDIT/LOAD)"
	run_capture "/index.html?mode=menu" "$REPO_ROOT/tools/godot/build/game_menu.png" "QA:MENU:SHOWCASE:DONE" 180000
	check_report "$REPO_ROOT/tools/godot/build/game_menu.png.json" || FAILURES=$((FAILURES+1))
	python3 - "$REPO_ROOT/tools/godot/build/game_menu.png.json" <<'MENUFLOW_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
saved = re.search(r"QA:SAVE:SAVED .*ticks=(\d+)", joined)
loaded = re.search(r"QA:SAVE:LOADED .*ticks=(\d+)", joined)
checks = {
    "boot fase MENU + waktu beku": has(r"QA:MENU:SCENE .*state=boot_menu .*speed=0"),
    "boot tanpa save + tombol MULAI": has(r"QA:MENU:SHOWCASE .*stage=boot .*primary=MULAI .*has_save=false"),
    "save nyata ditulis": saved is not None,
    "menu sesi: LANJUTKAN PERMAINAN": has(r"QA:MENU:CONTINUE_READY .*primary=LANJUTKAN PERMAINAN .*session=true"),
    "aksi resume (bukan reset)": has(r"QA:MENU:PLAY action=resume"),
    "menu dingin: tombol LANJUTKAN (save)": has(r"QA:MENU:COLD_READY .*primary=LANJUTKAN .*has_save=true"),
    "aksi load": has(r"QA:MENU:PLAY action=load"),
    "load mengembalikan ticks tersimpan": loaded is not None and saved is not None and loaded.group(1) == saved.group(1),
    "PENGATURAN membuka panel nyata M3 #5": has(r"QA:MENU:ACTION action=settings .*available=true")
        and has(r"QA:SET:PANEL_OPEN .*rows=\d+"),
    "KREDIT modal terbuka": has(r"QA:MENU:ACTION action=credits .*visible=true"),
    "panel menu fit": has(r"QA:MENU:FIT .* fit=ok") and has(r"QA:MENU:FIT .*credits_fit=ok"),
    "kembali ke COMMAND": has(r"QA:GAME:PHASE phase=COMMAND"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  MENU CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("  SAVE/LOAD ticks: saved=%s loaded=%s" % (saved.group(1) if saved else "?", loaded.group(1) if loaded else "?"))
print("REPORT game_menu.png.json (M3 #4 flow): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
MENUFLOW_PY
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "settings" ]; then
	echo "==> [settings] panel PENGATURAN M3 #5: audio/tampilan/ukuran UI/bahasa"
	run_capture "/index.html?mode=settings" "$REPO_ROOT/tools/godot/build/game_settings.png" "QA:SETTINGS:DONE" 180000
	check_report "$REPO_ROOT/tools/godot/build/game_settings.png.json" || FAILURES=$((FAILURES+1))
	python3 - "$REPO_ROOT/tools/godot/build/game_settings.png.json" <<'SET_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
checks = {
    "suite tanpa gagal": has(r"QA:SETTINGS:DONE passed=\d+ failed=0"),
    "bus audio nyata (SFX + Music)": has(r"QA:SET:APPLY") and has(r"TEST:PASS set.sfx_buses"),
    "slider → AudioServer bus": has(r"TEST:PASS set.master_applied") and has(r"TEST:PASS set.sfx_mute_at_zero"),
    "ukuran UI → HUD scale": has(r"TEST:PASS set.hud_scale_value") and has(r"TEST:PASS set.hud_scale_applied"),
    "bahasa → TranslationServer": has(r"TEST:PASS set.locale_en") and has(r"TEST:PASS set.tr_en_settings"),
    "persistensi user://settings.json": has(r"TEST:PASS set.persisted_file") and has(r"TEST:PASS set.reload_equal"),
    "reset default nyata": has(r"TEST:PASS set.reset_master") and has(r"QA:SET:PANEL_RESET"),
    "panel ≤560dp & di dalam layar": has(r"TEST:PASS set.panel_on_screen") and has(r"TEST:PASS set.panel_max_width_560dp"),
    "anti-tumpuk label/ikon": has(r"TEST:PASS set.chrome_labeled")
        and has(r"QA:SET:OVERLAP tag=\w+ count=0")
        and not has(r"QA:SET:OVERLAP tag=\w+ count=[1-9]"),
    "bank SFX prosedural tersimpan": has(r"TEST:PASS set.sfx_bank") and has(r"TEST:PASS set.sfx_click_duration"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  SETTINGS CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT game_settings.png.json (M3 #5 panel pengaturan): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
SET_PY
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
	python3 - "$REPO_ROOT/tools/godot/build/game_ui.png.json" <<'UIFLOW_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
checks = {
    "showcase UI selesai tanpa gagal": has(r"QA:UI:DONE passed=\d+ failed=0"),
    "PENGATURAN dari pause menu (M3 #5)": has(r"QA:UI:PAUSE_SETTINGS_OPEN .*open=true")
        and has(r"TEST:PASS ui.settings_open_from_pause")
        and has(r"TEST:PASS ui.settings_single_instance"),
    "panel pengaturan ditutup kembali dari pause menu": has(r"TEST:PASS ui.settings_closed_from_pause"),
    "anti-tumpuk panel pengaturan": has(r"QA:SET:OVERLAP tag=\w+ count=0")
        and not has(r"QA:SET:OVERLAP tag=\w+ count=[1-9]"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  UI CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT game_ui.png.json (M3 #5 jalur pause menu): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
UIFLOW_PY
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
