extends Node
## UI Showcase (M3 #1) — verifikasi otomatis + state siap untuk screenshot:
##   A: command mode + quest panel + selection (command core) + arrow
##      → marker QA:UI:SELECT_DONE
##   B: build menu terbuka + card terpilih → marker QA:UI:MENU_DONE
##   C: ship menu terbuka + card terpilih (M3 #2) → marker QA:UI:SHIP_DONE
##   D: pause menu buka/tutup (M3 #3) → marker QA:UI:PAUSE_DONE
## Semua ekspektasi dihitung dari res://data + state aktual (bukan asumsi).

var passed := 0
var failed := 0


func _ready() -> void:
	await get_tree().process_frame  ## tunggu base_scene siap (HQ ditempatkan)
	await get_tree().process_frame
	_run()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func check_eq(name: String, expected, actual) -> void:
	check(name, expected == actual, "expected=%s actual=%s" % [expected, actual])


func _hud() -> Control:
	var base := get_parent().get_node_or_null("BaseScene")
	if base == null:
		return null
	return base.get_node_or_null("HUD/HUDControl")


func _run() -> void:
	var bs: BuildingSystem = SystemRefs.building_system()
	var qt: QuestTracker = SystemRefs.quest_tracker()
	check("ui.systems_present", bs != null and qt != null)
	if bs == null or qt == null:
		_finish()
		return
	var hud := _hud()
	check("ui.hud_present", hud != null)
	if hud == null:
		_finish()
		return

	# --- Quest panel: 4 objektif slice, progress awal 0 ---
	check_eq("ui.quest_count", 4, qt.get_all().size())
	check_eq("ui.quest_initial", 0, qt.get_progress(&"q_power"))
	check("ui.quest_panel_visible", hud.get_node("QuestPanel").visible)

	# --- A: selection — command core terpilih via API publik HUD ---
	var hq: Building = bs.get_buildings_of(&"command_core")[0]
	hud.select_building(hq.instance_id)
	check_eq("ui.selected", hq.instance_id, hud.get_selected_instance())
	check("ui.sel_panel_visible", hud.get_node("SelectionPanel").visible)
	QaMarkers.marker("UI", "SELECT_DONE", {"instance": hq.instance_id, "level": hq.level})
	await get_tree().create_timer(1.2).timeout  ## settle untuk screenshot A

	# --- B: build menu — jumlah card = bangunan unlocked non-HQ (dari data) ---
	hud.open_build_menu()
	check("ui.menu_open", hud.is_build_menu_open())
	var bm: Control = hud.get_build_menu()
	var n_cards := int(bm.call("card_count"))
	var expected_cards := 0
	var pr := SystemRefs.progression_system()
	for id in pr.unlocked:
		var def := GameData.get_building_def(id)
		if def != null and def.category != "hq":
			expected_cards += 1
	check_eq("ui.menu_cards", expected_cards, n_cards)
	bm.call("select", &"energy_reactor")
	check_eq("ui.menu_selected", StringName(&"energy_reactor"), bm.call("get_selected"))
	QaMarkers.marker("UI", "MENU_DONE", {"cards": n_cards})
	await get_tree().create_timer(0.8).timeout  ## settle untuk screenshot B

	# --- C: ship menu (M3 #2) — jumlah card = kapal pemain (cost non-empty) ---
	hud.close_build_menu()
	hud.open_ship_menu()
	check("ui.ship_menu_open", hud.is_ship_menu_open())
	var sm: Control = hud.get_ship_menu()
	var n_ship_cards := int(sm.call("card_count"))
	var expected_ships := 0
	for id in GameData.ships.keys():
		var sdef := GameData.get_ship_def(id)
		if sdef != null and not sdef.cost.is_empty():
			expected_ships += 1
	check_eq("ui.ship_menu_cards", expected_ships, n_ship_cards)
	sm.call("select", &"shp_001_interceptor")
	check_eq("ui.ship_menu_selected", StringName(&"shp_001_interceptor"), sm.call("get_selected"))
	QaMarkers.marker("UI", "SHIP_DONE", {"cards": n_ship_cards})
	await get_tree().create_timer(0.8).timeout  ## settle untuk screenshot C

	# --- D: pause menu (M3 #3) — TimeSystem beku saat buka, lanjut saat tutup ---
	hud.close_ship_menu()
	hud.open_pause_menu()
	check("ui.pause_open", hud.is_pause_menu_open())
	check_eq("ui.pause_time_frozen", 0.0, TimeSystem.speed)
	check_eq("ui.pause_phase", GameManager.Phase.PAUSE, GameManager.phase)
	QaMarkers.marker("UI", "PAUSE_OPEN", {})
	await get_tree().create_timer(0.8).timeout  ## settle untuk screenshot D
	hud.close_pause_menu()
	check("ui.pause_closed", not hud.is_pause_menu_open())
	check_eq("ui.pause_time_resumed", 1.0, TimeSystem.speed)
	check_eq("ui.pause_phase_command", GameManager.Phase.COMMAND, GameManager.phase)
	QaMarkers.marker("UI", "PAUSE_DONE", {})
	_finish()


func _finish() -> void:
	print("UI:DONE passed=%d failed=%d" % [passed, failed])
	QaMarkers.marker("UI", "DONE", {"passed": passed, "failed": failed})
