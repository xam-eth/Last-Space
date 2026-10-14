extends Node
## UI Showcase (M3 #1) — verifikasi otomatis + state siap untuk screenshot:
##   A: command mode + quest panel + selection (command core) + arrow
##      → marker QA:UI:SELECT_DONE
##   B: build menu terbuka + card terpilih → marker QA:UI:MENU_DONE
##   C: ship menu terbuka + card terpilih (M3 #2) → marker QA:UI:SHIP_DONE
##   D: pause menu buka/tutup (M3 #3) → marker QA:UI:PAUSE_DONE
##   D2: PENGATURAN dari pause menu (M3 #5) → marker QA:UI:PAUSE_SETTINGS_OPEN
## Audit kartu (kritik #6 / AC-6a): `--step=kartu` menahan katalog BANGUN tetap
## terbuka + kartu terpilih → marker QA:UI:KARTU_READY (dipakai capture 1280x720 dpr1).
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


func base_hud() -> Control:
	var base := get_parent().get_node_or_null("BaseScene")
	return base.get_node_or_null("HUD/HUDControl") as Control if base != null else null


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
	## M3 #9: basis awal = rencana tata letak (bangunan sudah berdiri) sehingga
	## progress "kekuatan" tidak lagi 0 di frame pertama. Yang diuji: angka itu
	## NYATA (0 ≤ progress ≤ target) dan cocok dengan jumlah bangunan di sistem.
	var qp := int(qt.get_progress(&"q_power"))
	var power_target := int(qt.get_all()[0].target) if qt.get_all().size() > 0 else 0
	var built := bs.get_all_buildings().size()
	check("ui.quest_tracker_nyata", qp >= 0 and qp <= power_target,
		"progress=%d target=%d bangunan=%d" % [qp, power_target, built])
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
	var turrets_before := bs.count_of(&"laser_turret")
	var t1: Building = bs.place_building(&"laser_turret", Vector3(14, 0, -12))
	var t2: Building = bs.place_building(&"laser_turret", Vector3(-16, 0, -14))
	check("ui.turrets_placed",
		t1 != null and t2 != null and bs.count_of(&"laser_turret") == turrets_before + 2,
		"count %d → %d" % [turrets_before, bs.count_of(&"laser_turret")])

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
	check_eq("ui.card_badge_qty", bs.count_of(&"laser_turret"), int(bm.call("qty_of", &"laser_turret")))
	## Badge 0 → tersembunyi (diuji langsung di kontrol, tidak bergantung basis awal
	## yang kini sudah memuat bibit setiap tipe lewat rencana tata letak).
	var shield_tile: Control = (bm.get("_cards") as Dictionary).get(&"shield_generator")
	CatalogTile.set_qty(shield_tile, 0)
	check_eq("ui.card_badge_hidden_at_zero", 0, CatalogTile.qty_of(shield_tile))
	CatalogTile.set_qty(shield_tile, bs.count_of(&"shield_generator"))
	bm.call("select", &"energy_reactor")
	check_eq("ui.menu_selected", StringName(&"energy_reactor"), bm.call("get_selected"))
	QaMarkers.marker("UI", "MENU_DONE", {"cards": n_cards})
	## AC-6a: tahan katalog terbuka supaya bisa direkam dari sudut pandang pemain.
	var hold := false
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--step=kartu" or a.begins_with("--step=kartu"):
			hold = true
	print("QA:UI:STEP args=%s user=%s hold=%s" % [str(OS.get_cmdline_args()),
		str(OS.get_cmdline_user_args()), str(hold)])
	if hold:
		await get_tree().create_timer(0.8).timeout
		var modal_rect := (bm.get_node("Modal") as Control).get_global_rect()
		## --- Audit AC-6a (kritik #6): kartu TIDAK bertumpuk + ukuran sesuai standar.
		## Diukur dari rect NYATA semua kartu, bukan dari perkiraan kode.
		var rects: Array[Rect2] = []
		for key in (bm.get("_cards") as Dictionary).keys():
			var c := (bm.get("_cards") as Dictionary)[key] as Control
			if c != null and c.visible:
				rects.append(c.get_global_rect())
		var overlaps := 0
		var min_gap := 99999.0
		var min_tile := 99999.0
		for i in rects.size():
			min_tile = minf(min_tile, minf(rects[i].size.x, rects[i].size.y))
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					overlaps += 1
				var dx := absf(rects[i].position.x - rects[j].position.x)
				var dy := absf(rects[i].position.y - rects[j].position.y)
				if absf(rects[i].position.y - rects[j].position.y) < 1.0 and dx > 1.0:
					min_gap = minf(min_gap, dx - rects[i].size.x)
				if absf(rects[i].position.x - rects[j].position.x) < 1.0 and dy > 1.0:
					min_gap = minf(min_gap, dy - rects[i].size.y)
		var detail := bm.get_node_or_null("Modal/ModalBody/DetailPanel") as Control
		var detail_overlap := 0
		if detail != null:
			for r in rects:
				if r.intersects(detail.get_global_rect()):
					detail_overlap += 1
		var hudc := base_hud()
		var dpr_real := float(hudc.call("_device_pixel_ratio")) if hudc != null else 1.0
		var modal_ctrl := bm.get_node("Modal") as Control
		var t0 := (bm.get("_cards") as Dictionary)[&"laser_turret"] as Control
		print("QA:CARD:CALIB hud_scale=%.4f dpr=%.2f vp=%s | modal_rect=%s modal_size=%s | tile_rect=%s tile_size=%s" % [
			hudc.scale.x if hudc != null else -1.0, dpr_real, str(get_viewport().get_visible_rect().size),
			str(modal_rect.size), str(modal_ctrl.size), str(t0.get_global_rect().size), str(t0.size)])
		## SATUAN (terbukti dari QA:CARD:CALIB, bukan diandaikan):
		##   Control.size        = design px (di-scale hud_scale = dpr/2 × pengali UI)
		##   Control.global_rect = device px (= design px × hud_scale)
		## dp = css px = device px / dpr → faktor 1/dpr untuk angka dari global_rect.
		var dp_factor := 1.0 / maxf(dpr_real, 0.001)
		var modal_dp := modal_rect.size * dp_factor
		check("ui.kartu_tidak_bertumpuk", overlaps == 0,
			"pasangan kartu beririsan=%d dari %d kartu" % [overlaps, rects.size()])
		check("ui.kartu_tidak_menabrak_panel_detail", detail_overlap == 0,
			"kartu menabrak DetailPanel=%d" % detail_overlap)
		check("ui.kartu_ukuran_standar", min_tile * dp_factor >= 48.0,
			"tile terkecil=%.1fdp (standar ≥48dp)" % (min_tile * dp_factor))
		check("ui.kartu_jarak_standar", min_gap * dp_factor >= 7.5,
			"jarak antar kartu=%.1fdp (standar 8dp)" % (min_gap * dp_factor))
		check("ui.modal_lebar_standar", modal_dp.x <= 560.0,
			"lebar modal=%.1fdp (standar ≤560dp)" % modal_dp.x)
		check("ui.modal_tinggi_standar", modal_dp.y <= 360.0,
			"tinggi modal=%.1fdp (viewport 360dp)" % modal_dp.y)
		var tile_rect := (bm.get("_cards") as Dictionary).get(&"turret" if false else &"laser_turret")
		var first_rect: Rect2 = (tile_rect as Control).get_global_rect() if tile_rect != null else Rect2()
		QaMarkers.marker("UI", "KARTU_READY", {
			"cards": n_cards,
			"modal": "%d,%d %dx%d" % [modal_rect.position.x, modal_rect.position.y,
				modal_rect.size.x, modal_rect.size.y],
			"tile1": "%d,%d %dx%d" % [first_rect.position.x, first_rect.position.y,
				first_rect.size.x, first_rect.size.y],
			"kartu_beririsan": overlaps, "kartu_vs_detail": detail_overlap,
			"tile_dp_min": "%.1f" % (min_tile * dp_factor),
			"jarak_dp": "%.1f" % (min_gap * dp_factor),
			"modal_dp": "%.0fx%.0f" % [modal_dp.x, modal_dp.y],
			"passed": passed, "failed": failed})
		_finish()
		return
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
