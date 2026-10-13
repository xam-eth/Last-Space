extends RefCounted
## TestMainMenu — M3 #4: menu utama (GAMEPLAY_FLOW.md §3 Frame 3).
##
## Yang diuji (semua dari STATE NYATA, bukan teks yang di-hardcode):
##   - menu tanpa save → tombol utama MULAI → aksi "new" → fase COMMAND
##   - sesi berjalan → tombol utama LANJUTKAN PERMAINAN → aksi "resume"
##     (tick TIDAK di-reset: resume ≠ new game)
##   - save di disk → menu dingin → tombol utama LANJUTKAN → aksi "load" →
##     tick kembali ke nilai tersimpan (load sungguhan)
##   - PENGATURAN → dilaporkan jujur M3 #5 (tidak memulai game)
##   - KREDIT → modal buka/tutup
##   - ukuran tombol sesuai standar dp (56dp utama, 48dp sekunder)
##   - panel dihitung dari konten → tidak melimpah (fit) & muat di layar 360dp

const SAVE_PATH := "user://default.json"


func run(t) -> void:
	TestUtil.reset_all()
	var tree := Engine.get_main_loop() as SceneTree
	# bersihkan sisa save dari suite lain supaya state awal benar-benar "fresh"
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	## Fase MENU dipicu orkestrator (BaseScene.show_main_menu / pause menu) —
	## MainMenu.open() sendiri murni UI (tidak mengubah fase).
	GameManager.return_to_menu()
	var menu: Control = load("res://scripts/ui/main_menu.gd").new()
	tree.root.add_child(menu)  ## _ready → panel dibangun dari konten nyata
	menu.open()
	t.check("mm.open", menu.visible)
	t.check_eq("mm.no_save_initial", false, SaveSystem.has_save())

	# --- fit: panel = konten + margin, muat di design canvas 360dp ---
	var fit: Dictionary = menu.call("fit_report")
	t.check_eq("mm.fit", "ok", String(fit.get("fit", "")))
	t.check_eq("mm.credits_fit", "ok", String(fit.get("credits_fit", "")))
	t.check_eq("mm.primary_56dp", 112, int((menu.call("get_primary_button") as Button).custom_minimum_size.y))
	t.check_eq("mm.secondary_48dp", 96, int((menu.call("get_settings_button") as Button).custom_minimum_size.y))
	t.check_eq("mm.primary_dp_report", 56, int(fit.get("primary_dp", 0)))

	# --- tanpa save: tombol utama = MULAI, aksi = new, fase COMMAND ---
	var primary := menu.call("get_primary_button") as Button
	t.check("mm.primary_text_new", primary.text.find("MULAI") >= 0, primary.text)
	t.check_eq("mm.phase_menu_before_play", GameManager.Phase.MENU, GameManager.phase)
	var act: String = menu.call("press_primary")
	t.check_eq("mm.action_new", "new", act)
	t.check_eq("mm.phase_command_after_new", GameManager.Phase.COMMAND, GameManager.phase)
	t.check("mm.closed_after_play", not menu.visible)
	t.check_eq("mm.session_active", true, menu.call("is_session_active"))

	# --- sesi berjalan: tombol utama = LANJUTKAN PERMAINAN, aksi = resume ---
	GameManager.return_to_menu()
	menu.open()
	t.check("mm.primary_text_session", primary.text.find("LANJUTKAN PERMAINAN") >= 0, primary.text)
	var ticks_session := TimeSystem.tick_count
	var act2: String = menu.call("press_primary")
	t.check_eq("mm.action_resume", "resume", act2)
	t.check_eq("mm.phase_command_after_resume", GameManager.Phase.COMMAND, GameManager.phase)
	t.check_eq("mm.resume_keeps_ticks", ticks_session, TimeSystem.tick_count)

	# --- save nyata → menu dingin: tombol utama = LANJUTKAN, aksi = load ---
	TimeSystem.advance_ticks(200)
	var ticks_saved := TimeSystem.tick_count
	t.check("mm.save_written", SaveSystem.save_game())
	TimeSystem.advance_ticks(150)  ## waktu jalan lagi → load wajib mengembalikan
	t.check("mm.ticks_advanced", TimeSystem.tick_count > ticks_saved)
	GameManager.return_to_menu()
	menu.call("set_session_active", false)
	menu.open()
	t.check("mm.primary_text_cold", primary.text.find("LANJUTKAN") >= 0, primary.text)
	t.check("mm.save_summary_shown", _find_label(menu, "Simpanan: wave") != "")
	var act3: String = menu.call("press_primary")
	t.check_eq("mm.action_load", "load", act3)
	t.check_eq("mm.load_restores_ticks", ticks_saved, TimeSystem.tick_count)
	t.check_eq("mm.phase_command_after_load", GameManager.Phase.COMMAND, GameManager.phase)

	# --- play_requested ter-emit dengan aksi nyata (kontrak HUD/BaseScene) ---
	var seen := {"action": ""}
	menu.connect("play_requested", func(a: String): seen["action"] = a)
	GameManager.return_to_menu()
	menu.call("set_session_active", false)
	menu.open()
	menu.call("press_primary")
	t.check_eq("mm.signal_action_load", "load", String(seen["action"]))

	# --- save dibuat SAAT FASE MENU (skenario pemain) → load wajib ke COMMAND ---
	GameManager.return_to_menu()
	TimeSystem.advance_ticks(60)
	t.check("mm.save_while_menu", SaveSystem.save_game())
	var ticks_menu_save := TimeSystem.tick_count
	menu.call("set_session_active", false)
	menu.open()
	var act4: String = menu.call("press_primary")
	t.check_eq("mm.action_load_from_menu", "load", act4)
	t.check_eq("mm.load_from_menu_phase_command", GameManager.Phase.COMMAND, GameManager.phase)
	t.check_eq("mm.load_from_menu_ticks", ticks_menu_save, TimeSystem.tick_count)

	# --- PENGATURAN: jujur M3 #5, tidak memulai game ---
	GameManager.return_to_menu()
	menu.call("set_session_active", false)
	menu.open()
	menu.call("press_settings")
	## M3 #5: pengaturan sudah ADA → panel terbuka (dulu hanya status "M3 #5").
	var settings_panel = menu.call("get_settings_panel")
	t.check("mm.settings_panel_open", settings_panel != null and settings_panel.is_open(),
		"panel pengaturan terbuka dari menu utama")
	if settings_panel != null:
		settings_panel.call("close")
	t.check_eq("mm.settings_no_game_start", GameManager.Phase.MENU, GameManager.phase)

	# --- KREDIT: modal nyata buka/tutup ---
	var credits := menu.call("get_credits_panel") as Control
	menu.call("press_credits")
	t.check("mm.credits_open", credits.visible)
	menu.call("press_credits_close")
	t.check("mm.credits_closed", not credits.visible)

	menu.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	TestUtil.reset_all()


func _find_label(node: Node, needle: String) -> String:
	if node is Label and (node as Label).text.find(needle) >= 0:
		return (node as Label).text
	for c in node.get_children():
		var r := _find_label(c, needle)
		if r != "":
			return r
	return ""
