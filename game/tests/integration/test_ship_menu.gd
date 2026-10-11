extends RefCounted
## TestShipMenu — M3 #2: modal ship menu (GAMEPLAY_FLOW.md §3 Frame 6).
## Ekspektasi dari res://data: card = kapal pemain (cost non-empty),
## biaya dari .tres; produksi atomic (cek hangar + dana, tanpa partial spend).


func run(t) -> void:
	TestUtil.reset_all()
	var tree := Engine.get_main_loop() as SceneTree
	var menu: Control = load("res://scripts/ui/ship_menu.gd").new()
	tree.root.add_child(menu)  ## _ready jalan → kartu terbangun dari data
	menu.open()
	t.check("sm.open", menu.visible)

	# --- jumlah card = kapal pemain (cost non-empty, dari data) ---
	var expected := 0
	for id in GameData.ships.keys():
		var def := GameData.get_ship_def(id)
		if def != null and not def.cost.is_empty():
			expected += 1
	t.check_eq("sm.card_count", expected, menu.card_count())

	# --- pilih interceptor → detail terisi ---
	menu.select(&"shp_001_interceptor")
	t.check_eq("sm.selected", StringName(&"shp_001_interceptor"), menu.get_selected())

	# --- tanpa hangar → produce gagal, tanpa spend ---
	var def := GameData.get_ship_def(&"shp_001_interceptor")
	var e0 := Economy.get_amount(&"energy")
	var m0 := Economy.get_amount(&"minerals")
	var ps: ProductionSystem = SystemRefs.production_system()
	var q0 := ps.queue_count()
	t.check("sm.produce_fail_no_hangar", not menu.press_produce())
	t.check_eq("sm.no_spend_no_hangar_e", e0, Economy.get_amount(&"energy"))
	t.check_eq("sm.no_spend_no_hangar_m", m0, Economy.get_amount(&"minerals"))
	t.check_eq("sm.queue_unchanged", q0, ps.queue_count())

	# --- bangun hangar → produce OK: biaya dari .tres, antrian +1 ---
	# Catat saldo SETELAH place_building (quest q_hangar beri reward +100M —
	# ekspektasi dari state aktual, bukan asumsi).
	var bs: BuildingSystem = SystemRefs.building_system()
	bs.place_building(&"fighter_hangar", Vector3(20, 0, 20))
	var e1 := Economy.get_amount(&"energy")
	var m1 := Economy.get_amount(&"minerals")
	t.check("sm.produce_ok", menu.press_produce())
	t.check_eq("sm.cost_energy", e1 - int(def.cost.get("energy", 0)), Economy.get_amount(&"energy"))
	t.check_eq("sm.cost_minerals", m1 - int(def.cost.get("minerals", 0)), Economy.get_amount(&"minerals"))
	t.check_eq("sm.queue_plus1", q0 + 1, ps.queue_count())

	# --- tanpa dana → gagal (atomic, tanpa partial spend) ---
	Economy.set_state({"balances": {"energy": 0, "minerals": 0}, "caps": {"energy": 1000, "minerals": 500}})
	t.check("sm.produce_fail_no_funds", not menu.press_produce())
	t.check_eq("sm.no_partial_spend", 0, Economy.get_amount(&"energy"))
	t.check_eq("sm.queue_unchanged2", q0 + 1, ps.queue_count())

	# --- tutup ---
	menu.close()
	t.check("sm.closed", not menu.visible)
	menu.queue_free()
