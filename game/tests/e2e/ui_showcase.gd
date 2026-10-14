extends Node
## UI Showcase (M3 #1) — verifikasi otomatis + state siap untuk screenshot:
##   A: command mode + quest panel + selection (command core) + arrow
##      → marker QA:UI:SELECT_DONE
##   B: build menu terbuka + card terpilih → marker QA:UI:MENU_DONE
##   C: ship menu terbuka + card terpilih (M3 #2) → marker QA:UI:SHIP_DONE
##   D: pause menu buka/tutup (M3 #3) → marker QA:UI:PAUSE_DONE
##   D2: PENGATURAN dari pause menu (M3 #5) → marker QA:UI:PAUSE_SETTINGS_OPEN
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


func _modal_overflow(menu: Control) -> Array[String]:
	## Anak modal yang keluar dari rect modal > 2px = meluber (temuan M3.6/M3.7).
	## Isi ScrollContainer dikecualikan (memang bisa lebih tinggi — digeser).
	var modal := menu.get_node_or_null("Modal") as Control
	if modal == null:
		var missing: Array[String] = ["Modal tidak ada"]
		return missing
	var bad: Array[String] = []
	_walk_fit(modal, modal.get_global_rect().grow(2.0), bad)
	return bad


func _walk_fit(node: Node, limit: Rect2, bad: Array[String]) -> void:
	for c in node.get_children():
		if c is ScrollContainer:
			continue
		if c is Control:
			var ctrl := c as Control
			if ctrl.visible and not limit.encloses(ctrl.get_global_rect()):
				bad.append("%s@%s" % [ctrl.name, str(ctrl.get_global_rect())])
		_walk_fit(c, limit, bad)


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
	var quest_panel: Control = hud.find_child("QuestPanel", true, false) as Control
	check("ui.quest_panel_visible", quest_panel != null and quest_panel.visible,
		"QuestPanel %s" % ("ditemukan" if quest_panel != null else "TIDAK ditemukan di HUD"))

	# --- Audit label: SEMUA kontrol interaktif wajib punya label teks ---
	# (kriteria user 2026-10-12: "card 70% tidak ada label" → target 0 unlabeled)
	var au: Dictionary = hud.call("audit_labels")
	check("ui.labels_all", int((au["unlabeled"] as Array).size()) == 0,
		"total=%d labeled=%d unlabeled=%s" % [int(au["total"]), int(au["labeled"]), str(au["unlabeled"])])
	check("ui.labels_min_count", int(au["total"]) >= 10,
		"total kontrol interaktif=%d" % int(au["total"]))

	# --- A: selection — command core terpilih via API publik HUD ---
	var hq: Building = bs.get_buildings_of(&"command_core")[0]
	hud.select_building(hq.instance_id)
	check_eq("ui.selected", hq.instance_id, hud.get_selected_instance())
	var sel_panel: Control = hud.find_child("SelectionPanel", true, false) as Control
	check("ui.sel_panel_visible", sel_panel != null and sel_panel.visible,
		"SelectionPanel %s" % ("ditemukan" if sel_panel != null else "TIDAK ditemukan di HUD"))
	QaMarkers.marker("UI", "SELECT_DONE", {"instance": hq.instance_id, "level": hq.level})
	await get_tree().create_timer(1.2).timeout  ## settle untuk screenshot A

	# --- Bukti badge angka (elemen yang DIIZINKAN di card, kriteria user):
	# taruh 2 laser turret lewat API sistem (gratis) → tile katalog "x2".
	var t1: Building = bs.place_building(&"laser_turret", Vector3(14, 0, -12))
	var t2: Building = bs.place_building(&"laser_turret", Vector3(-16, 0, -14))
	check("ui.turrets_placed", t1 != null and t2 != null and bs.count_of(&"laser_turret") == 2,
		"count=%d" % bs.count_of(&"laser_turret"))

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

	# --- Kritik #4 (2026-10-13): card katalog 70% TANPA label teks — ikon/art
	# dominan, angka/badge boleh; label kata hanya di chrome menu ---
	var cau: Dictionary = bm.call("audit_cards")
	var cf_ratio := CatalogTile.label_free_ratio(cau)
	check("ui.cards_no_label", int(cau["with_text"]) == 0,
		"tiles=%d with_text=%d labels=%s" % [int(cau["tiles"]), int(cau["with_text"]), str(cau["detail"])])
	check("ui.cards_label_free_70", cf_ratio >= 0.70,
		"card tanpa label = %d%% (target ≥70%%)" % int(round(cf_ratio * 100.0)))
	check("ui.cards_icon_ratio", int(cau["icon_ratio"]) >= 60,
		"ikon = %d%% sisi tile (diukur dari layout nyata)" % int(cau["icon_ratio"]))
	var tabs := bm.get_node_or_null("Modal/ModalBody/CategoryTabs")
	check("ui.cards_tabs_icon_only", tabs != null and tabs.find_children("*", "Label", true, false).is_empty(),
		"tab tanpa label kata=%s" % str(tabs != null))
	await get_tree().process_frame  ## WAJIB: ukur setelah container menyusun anak
	await get_tree().process_frame
	var of_build := _modal_overflow(bm)
	check("ui.menu_fit_build", of_build.is_empty(), str(of_build))
	check_eq("ui.card_badge_qty", 2, int(bm.call("qty_of", &"laser_turret")))
	check_eq("ui.card_badge_hidden_at_zero", 0, int(bm.call("qty_of", &"shield_generator")))
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
	var sau: Dictionary = sm.call("audit_cards")
	check("ui.ship_cards_no_label", int(sau["with_text"]) == 0,
		"tiles=%d with_text=%d labels=%s" % [int(sau["tiles"]), int(sau["with_text"]), str(sau["detail"])])
	await get_tree().process_frame
	await get_tree().process_frame
	var of_ship := _modal_overflow(sm)
	check("ui.menu_fit_ship", of_ship.is_empty(), str(of_ship))
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

	# --- D2: PENGATURAN dari pause menu (M3 #5) — panel MILIK HUD, satu instance
	var pm: Control = hud.get_pause_menu()
	pm.call("_on_settings_pressed")
	check("ui.settings_open_from_pause", hud.is_settings_open())
	check("ui.settings_single_instance", pm.call("get_settings_panel") == hud.get_settings_panel(),
		"panel pengaturan sama dengan milik HUD (bukan salinan)")
	QaMarkers.marker("UI", "PAUSE_SETTINGS_OPEN", {"open": hud.is_settings_open()})
	await get_tree().create_timer(0.8).timeout  ## settle untuk screenshot D2
	hud.close_settings()
	check("ui.settings_closed_from_pause", not hud.is_settings_open())
	hud.close_pause_menu()
	check("ui.pause_closed", not hud.is_pause_menu_open())
	check_eq("ui.pause_time_resumed", 1.0, TimeSystem.speed)
	check_eq("ui.pause_phase_command", GameManager.Phase.COMMAND, GameManager.phase)
	QaMarkers.marker("UI", "PAUSE_DONE", {})
	_finish()


func _finish() -> void:
	print("UI:DONE passed=%d failed=%d" % [passed, failed])
	QaMarkers.marker("UI", "DONE", {"passed": passed, "failed": failed})
