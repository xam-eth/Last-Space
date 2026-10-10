extends Node
## Main — boot entry. Dispatch berdasarkan mode:
##   game  : game bisa dimainkan (default)
##   tests : jalankan test suite (data + unit + integration), hasil via console
##   e2e   : jalankan playthrough end-to-end dengan marker QA:LOOP:*
##
## Mode dideteksi dari command line args (--tests/--e2e) atau query string
## (?mode=tests / ?mode=e2e) sebagai fallback.


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
	return "game"
