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
# Usage: bash tools/godot/run_game_check.sh [all|tests|e2e|game|asset|sim|stress|ui|menu|settings|camera|perf]
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
# ikon rotate (berkas SVG asli) untuk prompt portrait di shell build
mkdir -p "$BUILD/assets/ui/icons"
cp "$REPO_ROOT/game/assets/ui/icons/rotate.svg" "$BUILD/assets/ui/icons/rotate.svg"
cp "$GODOT_WEB_DIR/godot.js" "$GODOT_WEB_DIR/game.wasm" "$BUILD/"
cp "$GODOT_WEB_DIR/audio.worklet.js" "$BUILD/game.audio.worklet.js"
cp "$GODOT_WEB_DIR/audio.position.worklet.js" "$BUILD/game.audio.position.worklet.js"

# --- sinkronkan build ke web/ (build WebGL yang di-COMMIT — untuk preview
# tanpa install tools apa pun; game jalan di WebGL, bukan di tools) ---
WEB_DIR="$REPO_ROOT/web"
mkdir -p "$WEB_DIR"
cp "$BUILD/index.html" "$WEB_DIR/index.html"
mkdir -p "$WEB_DIR/assets/ui/icons"
cp "$REPO_ROOT/game/assets/ui/icons/rotate.svg" "$WEB_DIR/assets/ui/icons/rotate.svg"
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

if [ "$MODE" = "all" ] || [ "$MODE" = "camera" ]; then
	echo "==> [camera] kamera Command Mode M3 #6: zoom (pinch/double tap/tombol) + pan"
	run_capture "/index.html?mode=camera" "$REPO_ROOT/tools/godot/build/game_camera.png" "QA:CAMERA:DONE" 180000
	check_report "$REPO_ROOT/tools/godot/build/game_camera.png.json" || FAILURES=$((FAILURES+1))
	python3 - "$REPO_ROOT/tools/godot/build/game_camera.png.json" <<'CAM_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
def num(pat):
    m = re.search(pat, joined)
    return float(m.group(1)) if m else None
span_default = num(r"QA:CAM:SPAN .*px=([0-9.]+)")        ## span pertama (default)
spans = re.findall(r"QA:CAM:SPAN .*px=([0-9.]+)", joined)
ratio = (float(spans[-1]) / float(spans[0])) if len(spans) >= 2 and float(spans[0]) > 1.0 else None
checks = {
    "rig siap + marker QA:CAM:READY": has(r"QA:CAM:READY .*zoom=1"),
    "suite showcase tanpa gagal": has(r"QA:CAMERA:DONE passed=\d+ failed=0"),
    "tombol HUD zoom (48dp) memindahkan kamera": has(r"TEST:PASS cam.button_zoom_in_moves_camera")
        and has(r"TEST:PASS cam.hud_button_size_48dp"),
    "jarak piksel landmark membesar saat zoom in": ratio is not None and ratio >= 1.30,
    "jarak piksel landmark mengecil saat tombol −": has(r"TEST:PASS cam.button_zoom_out"),
    "chip zoom ikut state nyata + reset": has(r"TEST:PASS cam.chip_updates")
        and has(r"TEST:PASS cam.chip_reset"),
    "gesture: wheel + double tap + pinch": has(r"TEST:PASS cam.gesture_wheel")
        and has(r"TEST:PASS cam.gesture_double_tap_close") and has(r"TEST:PASS cam.gesture_pinch"),
    # M3 #8 v2: klamp = FOKUS tetap di dalam plataran (bukan radius arbitrer —
    # clamp radius dibatalkan; lihat docs/m3_8_cards_camera/REPORT_M3_8.md).
    "pan menggeser kamera & fokus tetap di dalam plataran": has(r"TEST:PASS cam.pan_moves_camera")
        and has(r"TEST:PASS cam.pan_clamped"),
    "tap pendek tetap memilih bangunan setelah pan": has(r"TEST:PASS cam.tap_selects_after_pan"),
    "HUD tanpa tumpukan dengan cluster zoom": has(r"QA:HUD:OVERLAP count=0")
        and not has(r"QA:HUD:OVERLAP count=[1-9]"),
    "label dunia tidak menembus panel HUD (zoom)": has(r"QA:SCENE:LABEL_HUD_OVERLAP count=0")
        and not has(r"QA:SCENE:LABEL_HUD_OVERLAP count=[1-9]")
        and has(r"TEST:PASS cam.close_label_no_hud_overlap"),
    "deklutter BENAR-BENAR menyembunyikan label saat zoom dekat":
        has(r"QA:CAM:LABEL_CHECK step=checks .*overlap=0 .*hidden=[1-9]"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  CAMERA CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
if ratio is not None:
    print("  SPAN landmark: %.1f px → %.1f px (rasio %.2f)" % (float(spans[0]), float(spans[-1]), ratio))
print("REPORT game_camera.png.json (M3 #6 kamera): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
CAM_PY
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

if [ "$MODE" = "all" ] || [ "$MODE" = "input" ]; then
	echo "==> [input] interaksi KLIK nyata (event mouse sintetis): BANGUN/ARMADA/kartu/zoom/pause"
	run_capture "/index.html?mode=input" "$REPO_ROOT/tools/godot/build/game_input.png" "QA:INPUT:DONE" 420000
	check_report "$REPO_ROOT/tools/godot/build/game_input.png.json" || FAILURES=$((FAILURES+1))
	python3 - "$REPO_ROOT/tools/godot/build/game_input.png.json" <<'INPUT_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
checks = {
    "suite input 0 gagal": has(r"QA:INPUT:DONE passed=\d+ failed=0"),
    "klik BANGUN membuka modal": has(r"TEST:PASS input.build_menu_terbuka_oleh_klik"),
    "semua kartu katalog dapat diklik": has(r"TEST:PASS input.semua_kartu_dapat_diklik"),
    "klik kartu memilih item": has(r"TEST:PASS input.kartu_terpilih_oleh_klik"),
    "klik BANGUN masuk antrian nyata": has(r"TEST:PASS input.klik_bangun_masuk_antrian"),
    "tap arena memilih bangunan 3D": has(r"TEST:PASS input.tap_arena_memilih_bangunan"),
    # M3 #9: basis awal SUDAH punya hangar (rencana tata letak) → produksi kapal
    # masuk antrian; jalur "bangun hangar dulu" tetap berlaku bila ditolak.
    "klik ARMADA → kartu kapal → PRODUKSI menjawab": has(r"TEST:PASS input.ship_menu_terbuka_oleh_klik")
        and has(r"TEST:PASS input.kartu_kapal_terpilih")
        and has(r"TEST:PASS input.klik_produksi_terjawab")
        and (has(r"QA:INPUT:SHIP_PRODUCE enqueued=true")
            or has(r"TEST:PASS input.hangar_masuk_antrian")),
    "aksi ditolak SELALU dijawab (penolakan + toast, bukan tombol mati)":
        has(r"QA:UI:MESSAGE level=warning text=")
        and has(r"QA:BUILD:CONFIRM_REJECT .*reason=")
        and has(r"TEST:PASS input.konfirmasi_ditolak_dengan_alasan"),
    # M3 #9: chrome gameplay disembunyikan di mode penempatan (anti-tumpuk)
    "mode penempatan menyembunyikan chrome (tidak bertumpuk)":
        has(r"QA:HUD:PLACE_MODE chrome=hidden"),
    # M3 #9: alur DUA LANGKAH (katalog → hantu → KONFIRMASI) + validasi area
    "penempatan dua langkah: katalog tutup, mode hantu, validasi area":
        has(r"TEST:PASS input.katalog_tutup_setelah_bangun")
        and has(r"TEST:PASS input.mode_penempatan_aktif")
        and has(r"TEST:PASS input.bilah_penempatan_tampil")
        and has(r"TEST:PASS input.posisi_dalam_plataran_sah")
        and has(r"TEST:PASS input.validasi_luar_plataran_ditolak")
        and has(r"QA:BUILD:LAYOUT placed=\d+"),
    "klik zoom mengubah kamera + reset chip": has(r"TEST:PASS input.klik_zoom_mengubah_kamera")
        and has(r"TEST:PASS input.klik_chip_reset_zoom"),
    "drag kamera tidak mengubah seleksi": has(r"TEST:PASS input.drag_tidak_mengubah_seleksi"),
    "klik MENU → pause → LANJUT": has(r"TEST:PASS input.pause_menu_terbuka_oleh_klik")
        and has(r"TEST:PASS input.pause_tertutup_oleh_klik"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  INPUT CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT game_input.png.json (M3 #7 interaksi nyata): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
INPUT_PY
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "asset" ]; then
	echo "==> [asset] pilot asset SHP-001 di scene perwakilan (base game nyata)"
	run_capture "/index.html?mode=asset" "$REPO_ROOT/tools/godot/build/game_asset.png" "QA:ASSET:READY" 120000
	check_report "$REPO_ROOT/tools/godot/build/game_asset.png.json" || FAILURES=$((FAILURES+1))
	python3 - "$REPO_ROOT/tools/godot/build/game_asset.png.json" <<'ARENAPNG_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
logs = json.load(open(sys.argv[1])).get("consoleLogs", [])
joined = "\n".join(logs)
req = ["planet_gas_ringed", "moon_rocky", "nebula_cluster", "station_orbital"]
found = {k: re.search(r"QA:ARENA:PNG id=%s src=png" % k, joined) is not None for k in req}
ok = all(found.values())
for k, v in found.items():
    print("  ARENA PNG: %s dari PNG -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT arena PNG (M3 #7): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
ARENAPNG_PY
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
    # M3 #8: kartu katalog = 56dp (keluhan pemain "masih terlalu besar"),
    # 0 tumpukan, ukuran seragam, gap konsisten, di dalam panel modal.
    "kartu katalog 56dp": has(r"QA:CARD:SUMMARY .*tile_dp=56")
        and has(r"QA:CARD:SUMMARY .*icon_ratio=80"),
    "kartu tidak bertumpuk + ukuran seragam": has(r"QA:CARD:OVERLAP count=0 .*uniform=true inside_panel=true")
        and not has(r"QA:CARD:OVERLAP count=[1-9]")
        and not has(r"QA:CARD:OVERLAP .* uniform=false"),
    "gap antar kartu konsisten (≥8px)": has(r"QA:CARD:OVERLAP .*gap_px=(?:[89]|\d\d)\.\d\.\."),
    "audit layout kartu dijalankan (build + ship)": has(r"QA:CARD:LAYOUT .*menu=build .*ok=true")
        and has(r"QA:CARD:LAYOUT .*menu=ship .*ok=true"),
    # M3 #8: 2 cek ini dulu HILANG SENYAP (get_node salah induk → error Godot).
    "panel quest & seleksi benar-benar diuji": has(r"TEST:PASS ui.quest_panel_visible")
        and has(r"TEST:PASS ui.sel_panel_visible"),
    "TIDAK ada error 'Node not found' di console (cek tidak hilang senyap)":
        not has(r"Node not found"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  UI CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT game_ui.png.json (M3 #5 jalur pause menu): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
UIFLOW_PY

	echo "==> [ui] portrait 360dp (rotasi) — modal & kartu tidak terpotong (tindak lanjut audit M3 #8)"
	cd "$REPO_ROOT/tools/vision"
	node capture.mjs "/index.html?mode=ui" "$REPO_ROOT/tools/godot/build/game_ui_portrait.png" \
		360 780 --dpr 3 --serve "$BUILD" --wait-for "QA:UI:MENU_DONE" --timeout 240000 \
		--wait-until domcontentloaded --settle 2000 >/dev/null
	python3 - "$REPO_ROOT/tools/godot/build/game_ui_portrait.png.json" <<'UIPORT_PY' || FAILURES=$((FAILURES+1))
import json, sys, re
rep = json.load(open(sys.argv[1]))
logs = rep.get("consoleLogs", [])
joined = "\n".join(logs)
def has(pat):
    return re.search(pat, joined) is not None
checks = {
    "kartu tetap 56dp di portrait (tidak mengecil/membesar)": has(r"QA:CARD:SUMMARY .*tile_dp=56"),
    "modal menyusut ke ruang nyata (narrow)": has(r"QA:CARD:MODAL menu=build .*narrow=true")
        and has(r"QA:CARD:MODAL menu=ship .*narrow=true"),
    "kartu di dalam panel + di dalam layar (portrait)":
        has(r"QA:CARD:LAYOUT .*menu=build .*inside_panel=true .*ok=true")
        and has(r"QA:CARD:LAYOUT .*menu=ship .*inside_panel=true .*ok=true")
        and not has(r"inside_screen=false"),
    "0 tumpukan kartu di portrait": has(r"QA:CARD:OVERLAP count=0") and not has(r"QA:CARD:OVERLAP count=[1-9]"),
    "0 error halaman": len(rep.get("pageErrors", [])) == 0,
    "TIDAK ada error 'Node not found'": not has(r"Node not found"),
}
ok = all(checks.values())
for k, v in checks.items():
    print("  UI PORTRAIT CHECK: %s -> %s" % (k, "PASS" if v else "FAIL"))
print("REPORT game_ui_portrait.png.json (M3 #8 portrait): %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
UIPORT_PY
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
