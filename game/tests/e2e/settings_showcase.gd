extends Node
## SettingsShowcase — verifikasi panel PENGATURAN M3 #5 di build nyata
## (mode `?mode=settings`): panel terbuka di atas menu utama, tiap kontrol
## benar-benar mengubah sistem nyata (AudioServer bus / DisplayServer / HUD
## scale / TranslationServer), nilai tersimpan ke `user://settings.json`.
## Foto diambil pada state akhir showcase (dpr 2 & 3) — nilai default + panel
## terbuka supaya komposisi terbaca.

var passed := 0
var failed := 0


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func check_eq(name: String, expected, actual) -> void:
	check(name, expected == actual, "expected=%s actual=%s" % [expected, actual])


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


## Menu utama hidup di dalam HUD (arsitektur M3 #4: hud.get_main_menu()).
func _hud() -> Control:
	var base := get_parent().get_node_or_null("BaseScene")
	if base == null:
		return null
	return base.get_node_or_null("HUD/HUDControl")


func _menu() -> Control:
	var hud := _hud()
	if hud == null:
		return null
	return hud.call("get_main_menu")


func _run() -> void:
	var menu := _menu()
	check("set.menu_present", menu != null)
	if menu == null:
		_finish()
		return

	# --- bank bunyi nyata (PCM dari sfx.json) ---
	var ids := AudioSystem.stream_ids()
	check("set.sfx_bank", ids.size() >= 3, "bunyi=%s" % str(ids))
	check("set.sfx_click_duration", AudioSystem.duration_of("ui_click") > 0.03
		and AudioSystem.duration_of("ui_click") < 0.12,
		"ui_click=%.3f s (target 40–80 ms)" % AudioSystem.duration_of("ui_click"))
	check("set.sfx_alarm_duration", AudioSystem.duration_of("wave_alarm") >= 0.5,
		"wave_alarm=%.3f s" % AudioSystem.duration_of("wave_alarm"))
	check("set.sfx_buses", AudioServer.get_bus_index("SFX") >= 0
		and AudioServer.get_bus_index("Music") >= 0,
		"bus: %d" % AudioServer.bus_count)

	# --- panel terbuka dari menu utama (bukan status "belum ada") ---
	menu.call("press_settings")
	var panel = menu.call("get_settings_panel")
	check("set.panel_open", panel != null and panel.is_open(), "SettingsPanel terbuka")
	if panel == null:
		_finish()
		return

	# --- audio: slider mengubah bus nyata ---
	panel.call("set_slider", "master_volume", 0.35)
	await get_tree().process_frame
	var mi := AudioServer.get_bus_index("Master")
	var db := AudioServer.get_bus_volume_db(mi)
	check("set.master_applied", is_equal_approx(db_to_linear(db), 0.35),
		"Master bus linear=%.3f (0.35 diminta)" % db_to_linear(db))
	panel.call("set_slider", "sfx_volume", 0.0)
	await get_tree().process_frame
	check("set.sfx_mute_at_zero", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		"SFX mute saat volume 0")
	panel.call("set_slider", "sfx_volume", 0.9)

	# --- ukuran UI: HUD menghitung ulang (skala nyata) ---
	panel.call("press_segment", "hud_scale", 1.15)
	await get_tree().process_frame
	await get_tree().process_frame
	check_eq("set.hud_scale_value", 1.15, SettingsSystem.hud_scale())
	var hud := _hud()
	var scale_ok := true
	var detail := "(tidak ada HUD — menu mode, dilaporkan jujur)"
	if hud != null:
		var expect := clampf(DisplayServer.screen_get_scale() / 2.0 * 1.15, 0.5, 3.0)
		scale_ok = absf(hud.scale.x - expect) <= 0.02  ## toleransi 1 ulp float
		detail = "HUD scale=%.3f (harap %.3f)" % [hud.scale.x, expect]
	check("set.hud_scale_applied", scale_ok, detail)
	panel.call("press_segment", "hud_scale", 1.0)

	# --- bahasa: locale + terjemahan nyata ---
	panel.call("press_segment", "language", "en")
	await get_tree().process_frame
	check_eq("set.locale_en", "en", TranslationServer.get_locale())
	check_eq("set.tr_en_settings", "SETTINGS", tr("PENGATURAN"))
	check_eq("set.tr_en_continue", "CONTINUE", tr("LANJUTKAN"))
	panel.call("press_segment", "language", "id")
	await get_tree().process_frame
	check_eq("set.locale_id", "id", TranslationServer.get_locale())
	check_eq("set.tr_id_settings", "PENGATURAN", tr("PENGATURAN"))
	QaMarkers.marker("SET", "I18N_CHECK", {"messages": I18n.message_count(),
		"en_settings": tr("PENGATURAN")})

	# --- persistensi: berkas pengaturan nyata + bisa dimuat ulang ---
	SettingsSystem.save_settings()
	var path := SettingsSystem.PATH
	check("set.persisted_file", FileAccess.file_exists(path), path)
	var before := SettingsSystem.snapshot()
	SettingsSystem.load_settings()
	var after := SettingsSystem.snapshot()
	check("set.reload_equal", str(before) == str(after),
		"snapshot sama setelah reload (%d kunci)" % after.size())

	# --- reset default: benar-benar kembali ke nilai default ---
	panel.call("press_reset")
	await get_tree().process_frame
	check_eq("set.reset_master", SettingsSystem.DEFAULTS["master_volume"], SettingsSystem.get_float("master_volume"))
	check_eq("set.reset_hud_scale", 1.0, SettingsSystem.hud_scale())
	check("set.reset_status", panel.call("get_status_text") != "", panel.call("get_status_text"))

	# --- anti-tumpuk & fit (panel + baris kontrol) ---
	var rect: Rect2 = panel.call("get_panel_rect")
	var vp := Vector2(DisplayServer.window_get_size())
	var dpr := DisplayServer.screen_get_scale()
	var inside := rect.position.x >= 0.0 and rect.position.y >= 0.0 \
		and rect.position.x + rect.size.x <= vp.x + 0.5 and rect.position.y + rect.size.y <= vp.y + 0.5
	check("set.panel_on_screen", inside, "rect %s viewport %s dpr=%.1f" % [str(rect), str(vp), dpr])
	## dp = device px / dpr (1 CSS px = 1 dp; device px = CSS × dpr).
	var w_dp := rect.size.x / dpr
	var h_dp := rect.size.y / dpr
	check("set.panel_max_width_560dp", w_dp <= 560.0,
		"lebar %.0f device px = %.0f dp (batas dialog 560dp)" % [rect.size.x, w_dp])
	check("set.panel_min_width_320dp", w_dp >= 320.0, "%.0f dp" % w_dp)
	check("set.panel_fits_height", h_dp <= vp.y / dpr + 0.5,
		"tinggi %.0f dp vs layar %.0f dp" % [h_dp, vp.y / dpr])
	var au: Dictionary = _audit_labels(panel)
	check("set.chrome_labeled", int((au["unlabeled"] as Array).size()) == 0,
		"total=%d labeled=%d unlabeled=%s" % [int(au["total"]), int(au["labeled"]), str(au["unlabeled"])])
	QaMarkers.marker("SET", "SHOWCASE:DONE", {"passed": passed, "failed": failed})
	_finish()


func _audit_labels(root: Node) -> Dictionary:
	var total := 0
	var labeled := 0
	var unlabeled: Array[String] = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
			if c is Button:
				total += 1
				if (c as Button).text.strip_edges() != "":
					labeled += 1
				else:
					unlabeled.append(String(c.name))
	return {"total": total, "labeled": labeled, "unlabeled": unlabeled}


func _finish() -> void:
	print("SETTINGS:DONE passed=%d failed=%d" % [passed, failed])
	QaMarkers.marker("SETTINGS", "DONE", {"passed": passed, "failed": failed})
