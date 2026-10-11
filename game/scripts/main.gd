extends Node
## Main — boot entry. Dispatch berdasarkan mode:
##   game  : game bisa dimainkan (default)
##   tests : jalankan test suite (data + unit + integration), hasil via console
##   e2e   : jalankan playthrough end-to-end dengan marker QA:LOOP:*
##   asset : showcase pilot asset SHP-001 di scene perwakilan (QA:ASSET:*)
##   sim   : simulasi ekonomi headless ratusan hari (QA:SIM:*, DEV_PLAN M2 #2)
##   stress: pengukuran performa stress scene (QA:STRESS:*, DEV_PLAN M2 #3)
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
		_:
			GameManager.start_new_game()
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
	return "game"
