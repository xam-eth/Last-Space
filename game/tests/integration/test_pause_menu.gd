extends RefCounted
## TestPauseMenu — M3 #3: modal pause (GAMEPLAY_FLOW.md §3 Frame 8).
## Ekspektasi dari state aktual: TimeSystem beku saat buka, lanjut saat tutup,
## phase PAUSE ⇄ COMMAND, konfirmasi main menu → save (main menu belum ada,
## dilaporkan jujur — tidak fake).


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

	# --- main menu: konfirmasi → save; main menu belum ada (jujur) ---
	menu.open()
	menu._on_main_menu_pressed()
	t.check("pm.confirm_visible", menu.get_node("ConfirmPanel").visible)
	menu._on_confirm_yes()
	t.check("pm.confirm_hidden", not menu.get_node("ConfirmPanel").visible)
	t.check("pm.saved_message", _find_label(menu, "Progress saved") != "")
	## Main menu belum ada (M3 #4) → game tetap di-pause (jujur, tidak fake).
	t.check_eq("pm.phase_still_pause", GameManager.Phase.PAUSE, GameManager.phase)
	menu.close()
	t.check_eq("pm.phase_command_after_close", GameManager.Phase.COMMAND, GameManager.phase)
	menu.queue_free()


func _find_label(node: Node, needle: String) -> String:
	if node is Label and (node as Label).text.find(needle) >= 0:
		return (node as Label).text
	for c in node.get_children():
		var r := _find_label(c, needle)
		if r != "":
			return r
	return ""
