extends RefCounted
## TestPauseMenu — M3 #3: modal pause (GAMEPLAY_FLOW.md §3 Frame 8).
## Ekspektasi dari state aktual: TimeSystem beku saat buka, lanjut saat tutup,
## phase PAUSE ⇄ COMMAND, konfirmasi MAIN MENU → save + navigasi NYATA ke menu
## utama (M3 #4: fase MENU, waktu tetap beku).


func run(t) -> void:
	TestUtil.reset_all()
	TimeSystem.resume()  ## pastikan speed normal sebelum test
	var tree := Engine.get_main_loop() as SceneTree
	var menu: Control = load("res://scripts/ui/pause_menu.gd").new()
	tree.root.add_child(menu)

	# --- awal: game jalan (speed 1, phase COMMAND) ---
	t.check_eq("pm.speed_running", 1.0, TimeSystem.speed)
	t.check_eq("pm.phase_command", GameManager.Phase.COMMAND, GameManager.phase)

	# --- buka pause: TimeSystem beku + phase PAUSE ---
	menu.open()
	t.check("pm.open", menu.visible)
	t.check_eq("pm.speed_frozen", 0.0, TimeSystem.speed)
	t.check_eq("pm.phase_pause", GameManager.Phase.PAUSE, GameManager.phase)

	# --- tutup (resume): TimeSystem lanjut + phase COMMAND ---
	menu.close()
	t.check("pm.closed", not menu.visible)
	t.check_eq("pm.speed_resumed", 1.0, TimeSystem.speed)
	t.check_eq("pm.phase_command_back", GameManager.Phase.COMMAND, GameManager.phase)

	# --- PENGATURAN (M3 #5): tombol pause menu membuka panel NYATA ---
	menu.open()
	menu.call("_on_settings_pressed")
	## TANPA await: runner test bersifat SINKRON — suite yang menunggu frame
	## kehilangan cek setelah titik await (temuan: 8 cek hilang senyap).
	var sp = menu.call("get_settings_panel")
	t.check("pm.settings_panel_open", sp != null and sp.is_open(),
		"panel pengaturan terbuka dari pause menu")
	t.check("pm.settings_panel_shared", sp is SettingsPanel,
		"memakai komponen SettingsPanel yang sama dengan menu utama")
	if sp != null:
		sp.call("close")
	t.check("pm.settings_panel_closed", not sp.is_open())
	menu.close()
	menu.open()

	# --- MAIN MENU: konfirmasi → save + navigasi NYATA (M3 #4) ---
	menu.open()
	menu._on_main_menu_pressed()
	t.check("pm.confirm_visible", menu.get_node("ConfirmPanel").visible)
	var moved: bool = menu.return_to_main_menu()
	t.check("pm.confirm_hidden", not menu.get_node("ConfirmPanel").visible)
	t.check("pm.moved_to_menu", moved)
	t.check("pm.save_file_written", SaveSystem.has_save())
	t.check_eq("pm.phase_menu_after_confirm", GameManager.Phase.MENU, GameManager.phase)
	t.check("pm.pause_hidden_after_confirm", not menu.visible)
	## Menu utama juga beku (base idle) — waktu TIDAK ikut jalan di menu.
	t.check_eq("pm.time_frozen_in_menu", 0.0, TimeSystem.speed)
	## close() saat modal sudah hidden = no-op (tidak membalik fase ke COMMAND).
	menu.close()
	t.check_eq("pm.phase_menu_kept", GameManager.Phase.MENU, GameManager.phase)
	menu.queue_free()
	TestUtil.reset_all()  ## suite berikutnya mulai dari COMMAND (state bersih)


func _find_label(node: Node, needle: String) -> String:
	if node is Label and (node as Label).text.find(needle) >= 0:
		return (node as Label).text
	for c in node.get_children():
		var r := _find_label(c, needle)
		if r != "":
			return r
	return ""
