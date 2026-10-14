extends Node
## Main — boot entry. Dispatch berdasarkan mode:
##   game  : game bisa dimainkan (default)
##   tests : jalankan test suite (data + unit + integration), hasil via console
##   e2e   : jalankan playthrough end-to-end dengan marker QA:LOOP:*
##   asset : showcase pilot asset SHP-001 di scene perwakilan (QA:ASSET:*)
##   sim   : simulasi ekonomi headless ratusan hari (QA:SIM:*, DEV_PLAN M2 #2)
##   stress: pengukuran performa stress scene (QA:STRESS:*, DEV_PLAN M2 #3)
##   ui    : showcase UI M3 #1 (quest panel + building selected + build
##           menu; marker QA:UI:SELECT_DONE lalu QA:UI:MENU_DONE)
##   camera: showcase KAMERA Command Mode M3 #6 (zoom + pan). Langkah lewat
##           ?mode=camera&step=default|close|far|pan|auto (marker QA:CAM:*).
##   place : foto bukti MODE PENEMPATAN M3 #9 (?step=valid|invalid) — hantu +
##           bilah LETAKKAN/KONFIRMASI (marker QA:PLACE:READY)
##   input : verifikasi KLIK nyata (event mouse sintetis) — BANGUN/ARMADA/zoom
##           → marker QA:INPUT:DONE
##   settings: showcase PANEL PENGATURAN M3 #5 (audio/tampilan/ukuran UI/bahasa)
##           di atas menu utama — marker QA:SETTINGS:DONE
##   menu  : showcase MENU UTAMA M3 #4 (base idle + panel menu). Langkah
##           dipilih lewat ?mode=menu&step=load|settings|credits|continue|auto
##           (marker QA:MENU:*) — dipakai gate + foto multi-resolusi.
##
## Mode dideteksi dari command line args (--tests/--e2e/--asset/--sim/--stress)
## atau query string (?mode=tests / ?mode=e2e / ?mode=asset / ?mode=sim /
## ?mode=stress) sebagai fallback.


func _ready() -> void:
	var mode := _detect_mode()
	QaMarkers.marker("GAME", "MODE", {"mode": mode})
	match mode:
		"tests":
			var scene: PackedScene = load("res://scenes/tests/test_scene.tscn")
			add_child(scene.instantiate())
		"e2e":
			GameManager.start_new_game(12345)  ## seed tetap → e2e reproducible
			var base: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base.instantiate())
			var e2e = load("res://tests/e2e/e2e_playthrough.gd").new()
			add_child(e2e)
		"asset":
			GameManager.start_new_game(777)  ## seed tetap → reproducible
			var base3: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base3.instantiate())
			var chk = load("res://tests/e2e/asset_showcase.gd").new()
			add_child(chk)
		"sim":
			GameManager.start_new_game(4242)  ## seed tetap → simulasi reproducible
			var base4: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base4.instantiate())
			var sim = load("res://tests/e2e/economy_sim.gd").new()
			add_child(sim)
		"stress":
			GameManager.start_new_game(555)  ## seed tetap → reproducible
			var base5: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base5.instantiate())
			var st = load("res://tests/e2e/stress_scene.gd").new()
			add_child(st)
		"ui":
			GameManager.start_new_game(999)  ## seed tetap → reproducible
			var base6: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base6.instantiate())
			var ui = load("res://tests/e2e/ui_showcase.gd").new()
			add_child(ui)
		"camera":
			## M3 #6: gameplay nyata (COMMAND) + showcase zoom/pan kamera.
			GameManager.start_new_game(6161)
			var base9: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base9.instantiate())
			var cams = load("res://tests/e2e/camera_showcase.gd").new()
			add_child(cams)
		"place":
			## M3 #9: foto bukti mode PENEMPATAN (hantu + bilah LETAKKAN);
			## ?mode=place&step=valid|invalid.
			GameManager.start_new_game(6161)
			var base10: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base10.instantiate())
			var ps = load("res://tests/e2e/placement_showcase.gd").new()
			add_child(ps)
		"input":
			## M3 #7: verifikasi INTERAKSI NYATA (event mouse sintetis ke
			## viewport) — BANGUN/ARMADA/kartu/zoom/pause harus bisa diklik.
			GameManager.start_new_game(31337)
			var base9: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base9.instantiate())
			var isc = load("res://tests/e2e/input_showcase.gd").new()
			add_child(isc)
		"settings":
			## M3 #5: boot fase MENU (base idle) lalu buka panel pengaturan;
			## showcase memverifikasi tiap kontrol ke sistem nyata.
			var base8: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base8.instantiate())
			var ss = load("res://tests/e2e/settings_showcase.gd").new()
			add_child(ss)
		"menu":
			## M3 #4: TANPA start_new_game — boot tetap fase MENU seperti produksi
			## (base idle + panel menu); showcase yang menulis save nyata lalu
			## menguji jalur LANJUTKAN/RESUME/LOAD.
			var base7: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base7.instantiate())
			var ms = load("res://tests/e2e/menu_showcase.gd").new()
			add_child(ms)
		_:
			## M3 #4: root default TETAP game (requirement human) — index.html →
			## game, boot ke fase MENU dengan base 3D idle; tombol Play memanggil
			## GameManager.start_new_game / SaveSystem.load_game (Fase COMMAND).
			var base2: PackedScene = load("res://scenes/base/base_scene.tscn")
			add_child(base2.instantiate())
			QaMarkers.marker("GAME", "READY", {})


func _detect_mode() -> String:
	# Shell meneruskan mode sebagai command line args (Engine config `args` →
	# callMain → OS.get_cmdline_args). "--" menjadi pemisah user args.
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	if "--tests" in args or "--tests" in user_args:
		return "tests"
	if "--e2e" in args or "--e2e" in user_args:
		return "e2e"
	if "--asset" in args or "--asset" in user_args:
		return "asset"
	if "--sim" in args or "--sim" in user_args:
		return "sim"
	if "--stress" in args or "--stress" in user_args:
		return "stress"
	if "--ui" in args or "--ui" in user_args:
		return "ui"
	if "--menu" in args or "--menu" in user_args:
		return "menu"
	if "--settings" in args or "--settings" in user_args:
		return "settings"
	if "--input" in args or "--input" in user_args:
		return "input"
	if "--camera" in args or "--camera" in user_args:
		return "camera"
	if "--place" in args or "--place" in user_args:
		return "place"   ## M3 #9: foto bukti mode penempatan (hantu)
	return "game"
