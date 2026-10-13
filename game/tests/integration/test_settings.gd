extends RefCounted
## TestSettings — M3 #5: pengaturan (audio/tampilan/ukuran UI/bahasa) +
## panel pengaturan + SFX bank nyata. Ekspektasi dari sistem AKTUAL
## (AudioServer bus, DisplayServer, TranslationServer, berkas user://).

const PANEL := "res://scripts/ui/settings_panel.gd"


func run(t) -> void:
	TestUtil.reset_all()
	var tree := Engine.get_main_loop() as SceneTree

	# --- bersihkan state: mulai dari default, tanpa berkas lama ---
	var path := SettingsSystem.PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SettingsSystem.reset_defaults()

	# --- default = nilai desain (bukan asumsi test) ---
	for key in SettingsSystem.DEFAULTS.keys():
		t.check_eq("set.default_%s" % key, SettingsSystem.DEFAULTS[key], SettingsSystem.get_value(key))

	# --- bus SFX/Music ada → slider punya sasaran nyata ---
	t.check("set.bus_sfx", AudioServer.get_bus_index("SFX") >= 0, "bus SFX dibuat runtime")
	t.check("set.bus_music", AudioServer.get_bus_index("Music") >= 0)

	# --- audio: nilai linear → bus db (dibaca balik dari AudioServer) ---
	SettingsSystem.set_value("master_volume", 0.5)
	var mi := AudioServer.get_bus_index("Master")
	t.check("set.master_half", is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(mi)), 0.5),
		"Master bus = %.3f" % db_to_linear(AudioServer.get_bus_volume_db(mi)))
	SettingsSystem.set_value("sfx_volume", 0.0)
	var si := AudioServer.get_bus_index("SFX")
	t.check("set.sfx_zero_mutes", AudioServer.is_bus_mute(si), "mute saat 0")
	SettingsSystem.set_value("sfx_volume", 0.9)
	t.check("set.sfx_unmute", not AudioServer.is_bus_mute(si))
	t.check("set.volume_clamped", SettingsSystem.set_value("master_volume", 5.0)
		and is_equal_approx(SettingsSystem.get_float("master_volume"), 1.0),
		"nilai 5.0 di-clamp ke %.2f" % SettingsSystem.get_float("master_volume"))
	t.check("set.volume_negative_clamped", SettingsSystem.set_value("master_volume", -3.0)
		and is_equal_approx(SettingsSystem.get_float("master_volume"), 0.0),
		"nilai -3.0 di-clamp ke %.2f" % SettingsSystem.get_float("master_volume"))

	# --- ukuran UI: nilai sah 0,85/1,00/1,15 + clamp ---
	SettingsSystem.set_value("hud_scale", 1.15)
	t.check_eq("set.hud_scale_115", 1.15, SettingsSystem.hud_scale())
	SettingsSystem.set_value("hud_scale", 9.0)
	t.check_eq("set.hud_scale_clamped", 1.15, SettingsSystem.hud_scale())
	SettingsSystem.set_value("hud_scale", 1.0)

	# --- bahasa: locale + terjemahan nyata dari I18n ---
	SettingsSystem.set_value("language", "en")
	t.check_eq("set.locale_en", "en", TranslationServer.get_locale())
	t.check_eq("set.tr_en_pause", "RESUME", tr("LANJUT"))
	t.check_eq("set.tr_en_settings", "SETTINGS", tr("PENGATURAN"))
	SettingsSystem.set_value("language", "zz")  ## tidak dikenal → kembali ke default id
	t.check_eq("set.locale_invalid_falls_back", "id", SettingsSystem.language())
	t.check_eq("set.tr_id_pause", "LANJUT", tr("LANJUT"))
	t.check("set.i18n_messages", I18n.message_count() >= 30, "pesan terdaftar=%d" % I18n.message_count())

	# --- tampilan: fullscreen sesuai KENYATAAN platform (permintaan bisa ditolak
	# browser tanpa gesture pengguna → nilai disamakan dengan mode aktual) ---
	SettingsSystem.set_value("fullscreen", true)
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN 		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	t.check("set.fullscreen_truthful", SettingsSystem.get_bool("fullscreen") == is_full,
		"mode aktual=%d, nilai pengaturan=%s (jujur, tidak mengklaim)" % [mode, str(SettingsSystem.get_bool("fullscreen"))])
	SettingsSystem.set_value("fullscreen", false)
	t.check_eq("set.windowed_applied", DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.window_get_mode())

	# --- persistensi: tulis → ubah → muat ulang → sama ---
	SettingsSystem.set_value("master_volume", 0.35)
	SettingsSystem.set_value("language", "en")
	t.check("set.saved_file", FileAccess.file_exists(path), path)
	var snapshot := SettingsSystem.snapshot()
	SettingsSystem.reset_defaults()  ## merusak state in-memory + mengubah berkas
	t.check("set.reset_applied", is_equal_approx(SettingsSystem.get_float("master_volume"), 0.8),
		"master=%.2f setelah reset" % SettingsSystem.get_float("master_volume"))
	## Tulis ulang berkas dengan snapshot pertama, lalu load → harus sama.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema_version": SettingsSystem.SCHEMA, "values": snapshot}, "\t"))
	f.close()
	t.check("set.load_ok", SettingsSystem.load_settings())
	t.check("set.loaded_values_equal", str(snapshot) == str(SettingsSystem.snapshot()),
		"snapshot %s" % str(SettingsSystem.snapshot()))
	t.check("set.loaded_applied_bus",
		absf(db_to_linear(AudioServer.get_bus_volume_db(mi)) - 0.35) < 0.01,
		"Master bus=%.3f (harap 0.35) — load_settings MENERAPKAN nilai ke bus" % db_to_linear(AudioServer.get_bus_volume_db(mi)))

	# --- berkas rusak → default, tidak crash (jujur, bukan diam-diam) ---
	SettingsSystem.reset_defaults()  ## tulis berkas valid dulu (urutan penting)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{rusak")
	f.close()
	t.check("set.bad_file_no_load", not SettingsSystem.load_settings())
	t.check_eq("set.bad_file_keeps_default", 0.8, SettingsSystem.get_float("master_volume"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# --- SFX bank nyata (PCM dari sfx.json) ---
	t.check("set.sfx_streams", AudioSystem.stream_ids().size() >= 3, str(AudioSystem.stream_ids()))
	t.check("set.sfx_click_40_80ms",
		AudioSystem.duration_of("ui_click") >= 0.04 and AudioSystem.duration_of("ui_click") <= 0.08,
		"ui_click=%.3f s" % AudioSystem.duration_of("ui_click"))
	var before := int(AudioSystem.counts().get("ui_click", 0))
	AudioSystem.ui_click()
	t.check("set.sfx_click_counts", int(AudioSystem.counts().get("ui_click", 0)) == before + 1,
		"counter %d → %d" % [before, int(AudioSystem.counts().get("ui_click", 0))])

	# --- panel: API kontrol (SINKRON — runner test tidak menunggu frame;
	#     pengukuran layout/fit/anti-tumpuk diuji di showcase `?mode=settings`
	#     pada build nyata, di mana frame benar-benar berjalan) ---
	var panel: Control = load(PANEL).new()
	tree.root.add_child(panel)
	panel.call("open")
	t.check("set.panel_open", panel.call("is_open"))
	t.check("set.panel_has_controls", (panel.get("_rows") as Array).size() >= 10,
		"kontrol=%d" % (panel.get("_rows") as Array).size())
	panel.call("set_slider", "music_volume", 0.4)
	t.check_eq("set.panel_slider_applies", 0.4, SettingsSystem.get_float("music_volume"))
	panel.call("press_segment", "hud_scale", 1.15)
	t.check_eq("set.panel_segment_applies", 1.15, SettingsSystem.hud_scale())
	panel.call("press_segment", "language", "en")
	t.check_eq("set.panel_language", "en", TranslationServer.get_locale())
	panel.call("press_segment", "language", "id")
	panel.call("press_toggle", "fullscreen")
	var mode2 := DisplayServer.window_get_mode()
	var real_full := mode2 == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode2 == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	t.check("set.panel_toggle_applies", SettingsSystem.get_bool("fullscreen") == real_full,
		"nilai=%s mode nyata=%d (permintaan bisa ditolak platform — UI ikut nyata)"
			% [str(SettingsSystem.get_bool("fullscreen")), mode2])
	var fs_btn: Button = (panel.get("_segments") as Dictionary)["fullscreen"]
	t.check("set.panel_toggle_button_in_sync", fs_btn.button_pressed == SettingsSystem.get_bool("fullscreen"),
		"tombol pressed=%s nilai=%s" % [str(fs_btn.button_pressed), str(SettingsSystem.get_bool("fullscreen"))])
	panel.call("press_toggle", "fullscreen")
	panel.call("press_reset")
	t.check_eq("set.panel_reset_master", 0.8, SettingsSystem.get_float("master_volume"))
	## Satu ButtonGroup bersama per baris → eksklusivitas radio dijamin kontrol.
	var seg_hud: Dictionary = panel.get("_segments")["hud_scale"]
	var pressed := 0
	for b in seg_hud.values():
		if (b as Button).button_pressed:
			pressed += 1
	t.check_eq("set.panel_radio_exclusive", 1, pressed)
	t.check("set.panel_audit_labels", _unlabeled(panel).is_empty(),
		"kontrol tanpa label: %s" % str(_unlabeled(panel)))
	panel.call("close")
	t.check("set.panel_closed", not panel.call("is_open"))
	panel.queue_free()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _unlabeled(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
			if c is Button and (c as Button).text.strip_edges() == "":
				out.append(String(c.name))
	return out
