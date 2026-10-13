extends Node
## TestRunner — menjalankan seluruh test suite, mencetak hasil ke console:
##   TEST:PASS <name> <detail> / TEST:FAIL <name> <detail> / TEST:SKIP <name> <reason>
##   TESTS:DONE passed=X failed=Y skipped=Z
##
## Test yang file-nya belum ada (phase berikutnya) dilaporkan SKIP, bukan FAIL.
## Gate (QA_PLAN.md): sebuah phase lulus jika failed=0.

@onready var results_label: Label = %ResultsLabel

var passed_count := 0
var failed_count := 0
var skipped_count := 0


func _ready() -> void:
	## Tunggu 1 frame: selama setup awal tree, root masih "busy setting up
	## children" — test yang add_child (misal test_build_menu) bisa gagal.
	await get_tree().process_frame
	run_all()
	print("TESTS:DONE passed=%d failed=%d skipped=%d" % [passed_count, failed_count, skipped_count])
	if results_label != null:
		results_label.text = "TESTS: passed=%d failed=%d skipped=%d" % [passed_count, failed_count, skipped_count]
	QaMarkers.marker("TESTS", "DONE", {"passed": passed_count, "failed": failed_count, "skipped": skipped_count})


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed_count += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed_count += 1
		print("TEST:FAIL %s %s" % [name, detail])


func check_eq(name: String, expected, actual) -> void:
	check(name, expected == actual, "expected=%s actual=%s" % [expected, actual])


func run_all() -> void:
	# P1: data + unit (core)
	_run("data_validation", "res://tests/unit/test_data_validation.gd")
	_run("seeded_rng", "res://tests/unit/test_seeded_rng.gd")
	_run("economy", "res://tests/unit/test_economy.gd")
	# P2: integrasi ekonomi + bangunan
	_add_systems()
	_run("building_production", "res://tests/integration/test_building_production.gd")
	# P2b: edge cases ekonomi cross-system (ROADMAP M2)
	_run("economy_edge", "res://tests/integration/test_economy_edge.gd")
	# P3: armada + pertempuran
	_run("combat_simulator", "res://tests/unit/test_combat_simulator.gd")
	_run("combat_integration", "res://tests/integration/test_combat_integration.gd")
	# P4: progresi
	_run("progression", "res://tests/integration/test_progression.gd")
	# M3 #1/#2/#3: quest tracker + build + ship + pause menu (UI, Frame 4/5/6/8)
	_run("quest_tracker", "res://tests/integration/test_quest_tracker.gd")
	_run("build_menu", "res://tests/integration/test_build_menu.gd")
	_run("ship_menu", "res://tests/integration/test_ship_menu.gd")
	_run("pause_menu", "res://tests/integration/test_pause_menu.gd")
	# M3 #4: menu utama (Frame 3) — MULAI / LANJUTKAN (sesi) / LANJUTKAN (save)
	_run("main_menu", "res://tests/integration/test_main_menu.gd")
	# M3 #5: pengaturan (audio/tampilan/ukuran UI/bahasa) + panel + SFX bank
	_run("settings", "res://tests/integration/test_settings.gd")
	# P5: save/load
	_run("save_load", "res://tests/integration/test_save_load.gd")
	# M2: pilot asset SHP-001 (acceptance model + stress performa)
	_run("ship_model", "res://tests/integration/test_ship_model.gd")
	_run("ship_model_aln", "res://tests/integration/test_ship_model_aln.gd")
	_run("asset_stress", "res://tests/integration/test_asset_stress.gd")


func _run(name: String, path: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		skipped_count += 1
		print("TEST:SKIP %s file belum ada: %s" % [name, path])
		return
	var t = script.new()
	t.run(self)


func _add_systems() -> void:
	var specs := [
		"res://scripts/building/building_system.gd",
		"res://scripts/production/production_system.gd",
		"res://scripts/fleet/fleet_system.gd",
		"res://scripts/combat/wave_director.gd",
		"res://scripts/progression/progression_system.gd",
		"res://scripts/progression/quest_tracker.gd",
	]
	for path in specs:
		var script: GDScript = load(path)
		if script == null:
			continue
		add_child(script.new())
