extends Node
## MenuShowcase — bukti e2e MENU UTAMA (M3 #4, GAMEPLAY_FLOW.md §3 Frame 3).
##
## Dijalankan oleh mode `menu` (main.gd): scene base hidup, lalu showcase
## memindahkan game ke fase MENU dan memverifikasi jalur nyata:
##   boot MENU (base idle, tanpa save) → save nyata ditulis SaveSystem →
##   menu "LANJUTKAN (sesi)" → resume → menu dingin "LANJUTKAN" → LOAD nyata
##   (tick_count kembali ke nilai tersimpan) → PENGATURAN (jujur M3 #5) →
##   KREDIT (modal) → selesai.
##
## Langkah dipilih lewat `--step=<x>` (shell: ?mode=menu&step=x):
##   auto     : jalur penuh + marker QA:MENU:SHOWCASE:DONE (dipakai gate)
##   continue : berhenti di menu "LANJUTKAN PERMAINAN" (foto)
##   load     : berhenti setelah LOAD nyata → COMMAND (foto)
##   settings : berhenti setelah PENGATURAN ditekan (foto)
##   credits  : berhenti setelah modal KREDIT terbuka (foto)
##   from_pause: buka pause menu di gameplay → MAIN MENU → konfirmasi YA
##              (Frame 8 → Frame 3 dengan save nyata) lalu berhenti (foto)
##
## Nilai yang dicetak = state NYATA (tick_count, has_save, teks tombol) —
## bukan konstanta (AI_GOVERNANCE.md §13).

var _step := "auto"
var _base: Node
var _hud: Node
var _menu: Control
var _fail_count := 0


func _ready() -> void:
	_step = _detect_step()
	QaMarkers.marker("MENU", "SHOWCASE", {"step": _step})
	_base = _find_base()
	await get_tree().process_frame
	await get_tree().process_frame
	_menu = _find_menu()
	_hud = _base.get_node_or_null("HUD/HUDControl") if _base != null else null
	_check(_menu != null, "menu node ada")
	if _menu == null:
		QaMarkers.marker("MENU", "SHOWCASE:DONE", {"step": _step, "fail": _fail_count})
		return
	match _step:
		"continue":
			await _to_continue_state()
		"load":
			await _to_continue_state()
			QaMarkers.marker("MENU", "COLD_READY", {"primary": _text_of_primary(),
				"has_save": SaveSystem.has_save(), "ticks": TimeSystem.tick_count})
			_hud.call("close_main_menu")
			_base.call("show_main_menu", false)  ## menu DINGIN → tombol LANJUTKAN
			await get_tree().process_frame
			_leave_menu_by_primary("load")
		"settings":
			await _to_continue_state()
			_menu.call("press_settings")
			## M3 #5: PENGATURAN = panel nyata (audio/tampilan/ukuran UI/bahasa),
			## bukan lagi status teks "belum ada".
			var sp = _menu.call("get_settings_panel")
			QaMarkers.marker("MENU", "SETTINGS_READY",
				{"panel_open": sp != null and sp.is_open(), "status": _status_text()})
		"from_pause":
			await _from_pause_flow()
		"credits":
			await _to_continue_state()
			_menu.call("press_credits")
			QaMarkers.marker("MENU", "CREDITS_READY",
				{"visible": (_menu.call("get_credits_panel") as Control).visible})
		_:
			await _full_flow()
	QaMarkers.marker("MENU", "SHOWCASE:DONE", {"step": _step, "fail": _fail_count})


## Jalur penuh (gate): boot → save nyata → sesi → resume → dingin → LOAD.
func _full_flow() -> void:
	# 1) boot MENU: base idle, tanpa save.
	_check(GameManager.phase == GameManager.Phase.MENU, "boot fase MENU")
	_check(TimeSystem.speed <= 0.0, "waktu beku di menu (speed=%s)" % TimeSystem.speed)
	_check(not SaveSystem.has_save(), "belum ada save di boot")
	_check(_text_of_primary().find("MULAI") >= 0, "tombol utama boot = MULAI")
	QaMarkers.marker("MENU", "SHOWCASE", {"stage": "boot", "primary": _text_of_primary(),
		"has_save": SaveSystem.has_save(), "speed": TimeSystem.speed})

	# 2) tulis save NYATA (state berbeda: 1 bangunan + 60 detik waktu game).
	var bs := SystemRefs.building_system()
	var ps := SystemRefs.production_system()
	var placed: StringName = &"energy_reactor"
	if bs != null and ps != null:
		bs.place_building(placed, Vector3(6, 0, 0))
	TimeSystem.advance_ticks(600)  ## 60 detik game (deterministik, tanpa frame)
	var ticks_saved := TimeSystem.tick_count
	var saved := SaveSystem.save_game()
	_check(saved, "save nyata berhasil")
	QaMarkers.marker("MENU", "SHOWCASE", {"stage": "save", "saved": saved,
		"ticks": ticks_saved, "has_save": SaveSystem.has_save()})

	# 3) kembali ke menu dari gameplay (jalur pause menu) → "LANJUTKAN PERMAINAN".
	await _to_continue_state()

	# 4) tombol utama = RESUME sesi (bukan reset, bukan load).
	var buildings_before := bs.count_of(placed) if bs != null else 0
	var act := _leave_menu_by_primary("resume")
	_check(act == "resume", "aksi=resume (bukan reset/load)")
	_check(GameManager.phase == GameManager.Phase.COMMAND, "fase COMMAND setelah resume")
	_check(TimeSystem.speed > 0.0, "waktu jalan setelah resume")
	_check(bs.count_of(placed) == buildings_before, "state sesi tidak di-reset")
	_check(TimeSystem.tick_count >= ticks_saved, "tick sesi lanjut (bukan restart)")

	# 5) menu DINGIN dengan save di disk → tombol utama = LANJUTKAN → LOAD nyata.
	TimeSystem.advance_ticks(300)  ## waktu jalan lagi → load wajib mengembalikan
	var ticks_before_load := TimeSystem.tick_count
	_hud.call("close_main_menu")
	_base.call("show_main_menu", false)  ## menu dingin (session=false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not _menu.call("is_session_active"), "menu dingin (bukan sesi)")
	_check(_text_of_primary().find("LANJUTKAN") >= 0, "tombol utama = LANJUTKAN")
	QaMarkers.marker("MENU", "COLD_READY", {"primary": _text_of_primary(),
		"has_save": SaveSystem.has_save(), "ticks": ticks_before_load})
	var act2 := _leave_menu_by_primary("load")
	_check(act2 == "load", "aksi=load (dari save)")
	_check(TimeSystem.tick_count == ticks_saved,
		"tick kembali ke nilai tersimpan (%d == %d)" % [TimeSystem.tick_count, ticks_saved])
	_check(GameManager.phase == GameManager.Phase.COMMAND, "fase COMMAND setelah load")
	_check(bs.count_of(placed) == buildings_before, "bangunan dari save pulih")
	QaMarkers.marker("MENU", "LOADED", {"action": act2, "ticks": TimeSystem.tick_count,
		"expected": ticks_saved, "buildings": bs.count_of(placed) if bs != null else -1})

	# 6) PENGATURAN (jujur: M3 #5) + KREDIT (modal nyata) — dari menu dingin.
	_base.call("show_main_menu", false)
	await get_tree().process_frame
	_menu.call("press_settings")
	await get_tree().process_frame
	## M3 #5: panel pengaturan NYATA terbuka dari menu dingin (dulu status teks).
	var sp := _menu.call("get_settings_panel") as Control
	_check(sp != null and sp.is_open(), "PENGATURAN membuka panel pengaturan nyata")
	if sp != null:
		sp.call("close")
	_check(not sp.is_open(), "panel pengaturan bisa ditutup dari dalam")
	_menu.call("press_credits")
	var cp := _menu.call("get_credits_panel") as Control
	_check(cp != null and cp.visible, "modal KREDIT terbuka")
	_menu.call("press_credits_close")
	_check(not cp.visible, "modal KREDIT tertutup")
	QaMarkers.marker("MENU", "ACTIONS_DONE", {"settings": "panel_open",
		"credits": "modal", "status": _status_text()})
	# 6b) keluar dari menu DINGIN → tombol utama = LANJUTKAN → LOAD nyata
	_leave_menu_by_primary("load")

	# 7) jalur PAUSE MENU → MENU UTAMA (Frame 8 → Frame 3) juga diuji di gate.
	await _from_pause_flow()
	# 8) tombol utama di menu sesi = RESUME (state akhir: gameplay jalan)
	_leave_menu_by_primary("resume")


## Jalur pause menu (Frame 8) → menu utama (Frame 3): save + navigasi nyata.
func _from_pause_flow() -> void:
	var pause_menu: Control = _hud.call("get_pause_menu")
	_check(pause_menu != null, "pause menu ada")
	if pause_menu == null:
		return
	_hud.call("open_pause_menu")
	await get_tree().process_frame
	_check(pause_menu.visible, "pause menu terbuka di gameplay")
	pause_menu.call("_on_main_menu_pressed")  ## tampilkan konfirmasi
	var moved: bool = pause_menu.call("return_to_main_menu")  ## save + navigasi
	await get_tree().process_frame
	await get_tree().process_frame
	_check(moved, "save + navigasi ke menu utama")
	_check(GameManager.phase == GameManager.Phase.MENU, "fase MENU dari pause")
	_check(_menu.call("is_open"), "menu utama terbuka")
	_check(_menu.call("is_session_active"), "sesi aktif → LANJUTKAN PERMAINAN")
	_check(not pause_menu.visible, "pause menu tertutup")
	QaMarkers.marker("MENU", "FROM_PAUSE_READY", {"primary": _text_of_primary(),
		"has_save": SaveSystem.has_save(), "phase": GameManager.get_phase_name(),
		"speed": TimeSystem.speed})


## Bawa game ke state menu "LANJUTKAN PERMAINAN" (sesi aktif) + marker foto.
func _to_continue_state() -> void:
	if not SaveSystem.has_save():
		TimeSystem.advance_ticks(120)
		SaveSystem.save_game()
	var ticks := TimeSystem.tick_count
	EventBus.main_menu_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_menu.call("is_open"), "menu terbuka")
	_check(GameManager.phase == GameManager.Phase.MENU, "fase MENU")
	_check(TimeSystem.speed <= 0.0, "waktu beku di menu")
	var fit: Dictionary = _menu.call("fit_report")
	_check(String(fit.get("fit", "")) == "ok", "panel menu fit (fit=%s panel=%s avail=%s)" % [
		fit.get("fit"), fit.get("panel"), fit.get("avail")])
	_check(String(fit.get("credits_fit", "")) == "ok", "modal kredit fit (credits=%s)" % fit.get("credits"))
	QaMarkers.marker("MENU", "CONTINUE_READY", {"primary": _text_of_primary(),
		"has_save": SaveSystem.has_save(), "session": _menu.call("is_session_active"),
		"ticks": ticks, "speed": TimeSystem.speed})


func _leave_menu_by_primary(expected: String) -> String:
	var act: String = _menu.call("press_primary")
	QaMarkers.marker("MENU", "PLAY", {"action": act, "expected": expected,
		"phase": GameManager.get_phase_name(), "ticks": TimeSystem.tick_count,
		"speed": TimeSystem.speed})
	_check(act == expected, "aksi %s (nyata=%s)" % [expected, act])
	_check(not _menu.call("is_open"), "menu tertutup setelah Play")
	return act


# ------------------------------------------------------------------ util ---
func _check(ok: bool, label: String) -> void:
	if ok:
		print("TEST:PASS menu.e2e.%s" % label)
	else:
		_fail_count += 1
		print("TEST:FAIL menu.e2e.%s" % label)


func _text_of_primary() -> String:
	var b := _menu.call("get_primary_button") as Button
	return "" if b == null else b.text


func _status_text() -> String:
	var lbl := _menu.get_node_or_null("MenuPanel/MenuBody/Status") as Label
	return "" if lbl == null else lbl.text


func _find_base() -> Node:
	for c in get_parent().get_children():
		if c.name == "BaseScene":
			return c
	return null


func _find_menu() -> Control:
	if _base == null:
		return null
	var hud := _base.get_node_or_null("HUD/HUDControl")
	if hud == null:
		return null
	return hud.call("get_main_menu") as Control


func _detect_step() -> String:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if String(a).begins_with("--step="):
			return String(a).trim_prefix("--step=")
	return "auto"
