extends RefCounted
## TestBuildMenu — M3 #1: modal build menu (GAMEPLAY_FLOW.md §3 Frame 5).
## Ekspektasi dari res://data: jumlah card = bangunan unlocked non-HQ,
## biaya dari base_cost .tres; konstruksi atomic (tanpa partial spend).


func run(t) -> void:
	TestUtil.reset_all()
	var tree := Engine.get_main_loop() as SceneTree
	var menu: Control = load("res://scripts/ui/build_menu.gd").new()
	tree.root.add_child(menu)  ## _ready jalan → kartu terbangun dari data
	menu.open()
	t.check("bm.open", menu.visible)

	# --- jumlah card = bangunan unlocked non-HQ (dihitung dari data) ---
	var pr := SystemRefs.progression_system()
	var expected := 0
	for id in pr.unlocked:
		var def := GameData.get_building_def(id)
		if def != null and def.category != "hq":
			expected += 1
	t.check_eq("bm.card_count", expected, menu.card_count())

	# --- pilih reactor → detail terisi ---
	menu.select(&"energy_reactor")
	t.check_eq("bm.selected", StringName(&"energy_reactor"), menu.get_selected())

	# --- BUILD: biaya terpotong sesuai base_cost .tres, antrian +1 ---
	var def := GameData.get_building_def(&"energy_reactor")
	var e0 := Economy.get_amount(&"energy")
	var m0 := Economy.get_amount(&"minerals")
	var ps: ProductionSystem = SystemRefs.production_system()
	var q0 := ps.queue_count()
	t.check("bm.build_ok", menu.press_build())
	t.check_eq("bm.cost_energy", e0 - int(def.base_cost.get("energy", 0)), Economy.get_amount(&"energy"))
	t.check_eq("bm.cost_minerals", m0 - int(def.base_cost.get("minerals", 0)), Economy.get_amount(&"minerals"))
	t.check_eq("bm.queue_plus1", q0 + 1, ps.queue_count())

	# --- saldo habis → build gagal (atomic, tanpa partial spend) ---
	Economy.set_state({"balances": {"energy": 0, "minerals": 0}, "caps": {"energy": 1000, "minerals": 500}})
	t.check("bm.build_fail_no_funds", not menu.press_build())
	t.check_eq("bm.no_partial_spend", 0, Economy.get_amount(&"energy"))
	t.check_eq("bm.queue_unchanged", q0 + 1, ps.queue_count())

	# --- tutup ---
	menu.close()
	t.check("bm.closed", not menu.visible)
	menu.queue_free()
