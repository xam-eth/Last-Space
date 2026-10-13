extends Control
## PauseMenu — modal pause (GAMEPLAY_FLOW.md §3 Frame 8, M3 #3).
## Tombol: RESUME (56dp), SETTINGS (48dp), MAIN MENU (48dp + konfirmasi).
##
## Ukuran (design canvas, UI_UX_DESIGN.md §3): modal 480×360 (240×180dp),
## anchor center semua aspek; tombol besar tinggi 56dp/48dp (UI_UX_DESIGN §4).
##
## Aturan: saat pause, TimeSystem.pause (ekonomi/wave beku) + GameManager
## phase PAUSE; resume → TimeSystem.resume + phase COMMAND. MAIN MENU
## konfirmasi → SaveSystem.save_game lalu NAVIGASI NYATA ke menu utama
## (M3 #4: fase MENU + EventBus.main_menu_requested → BaseScene/HUD menampilkan
## MainMenu dengan tombol "LANJUTKAN PERMAINAN"; waktu tetap beku — base idle).

const MODAL_W := 480   ## 240dp
const MODAL_H := 360   ## 180dp
const TITLE_H := 64    ## 32dp
const BTN_BIG_H := 112 ## 56dp (tombol utama)
const BTN_H := 96      ## 48dp
const ICONS_JSON := "res://assets/ui/icons.json"

const C_PANEL := Color(0.043, 0.063, 0.125, 0.92)
const C_BORDER := Color(0.208, 0.816, 1.0, 0.55)
const C_CARD := Color(0.055, 0.082, 0.16, 0.9)
const C_BORDER_SEL := Color(0.208, 0.816, 1.0, 1.0)
const C_BORDER_DANGER := Color(1.0, 0.36, 0.36, 0.6)
const C_TEXT := Color(0.918, 0.965, 1.0, 1.0)
const C_MUTED := Color(0.62, 0.70, 0.80, 1.0)
const C_ACCENT := Color(0.208, 0.816, 1.0, 1.0)
const C_DANGER := Color(1.0, 0.36, 0.36, 1.0)

var _dim: ColorRect
var _modal: Panel
var _status: Label
var _confirm: Panel
var _settings_panel: SettingsPanel = null  ## M3 #5: panel pengaturan bersama
var _icon_cache: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  ## saat hidden tidak blok arena
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  ## klik luar = resume
	_dim.gui_input.connect(func(_e): close())
	add_child(_dim)

	_modal = Panel.new()
	_modal.name = "Modal"
	_modal.custom_minimum_size = Vector2(MODAL_W, MODAL_H)
	## Anchor CENTER — selalu di tengah semua aspek layar.
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.offset_left = -MODAL_W / 2.0
	_modal.offset_right = MODAL_W / 2.0
	_modal.offset_top = -MODAL_H / 2.0
	_modal.offset_bottom = MODAL_H / 2.0
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(24)  ## 12dp
	style.set_border_width_all(2)    ## 1dp
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	_modal.add_theme_stylebox_override("panel", style)
	add_child(_modal)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)  ## 8dp — kelipatan grid Material
	_modal.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0, TITLE_H)
	title_row.add_theme_constant_override("separation", 16)
	vbox.add_child(title_row)
	var title := Label.new()
	title.label_settings = _ls(32, C_TEXT)
	title.text = "DIJEDA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.custom_minimum_size = Vector2(180, 96)  ## 48dp tinggi (touch target)
	close_btn.text = "TUTUP"
	close_btn.icon = _load_icon("close")
	close_btn.add_theme_constant_override("icon_max_width", 48)  ## ikon 24dp
	close_btn.add_theme_font_size_override("font_size", 22)      ## 11dp labelSmall
	close_btn.add_theme_stylebox_override("normal", _close_style(C_BORDER))
	close_btn.add_theme_stylebox_override("hover", _close_style(C_BORDER_SEL))
	close_btn.add_theme_stylebox_override("pressed", _close_style(C_ACCENT))
	close_btn.pressed.connect(close)
	title_row.add_child(close_btn)

	var resume_btn := Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.custom_minimum_size = Vector2(0, BTN_BIG_H)  ## 56dp tombol utama
	resume_btn.text = "LANJUT"
	resume_btn.add_theme_font_size_override("font_size", 30)
	_style_button(resume_btn, C_ACCENT, C_TEXT)
	resume_btn.pressed.connect(close)
	vbox.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.custom_minimum_size = Vector2(0, BTN_H)  ## 48dp
	settings_btn.text = "PENGATURAN"
	settings_btn.add_theme_font_size_override("font_size", 26)
	_style_button(settings_btn, C_BORDER, C_TEXT)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	var menu_btn := Button.new()
	menu_btn.name = "MainMenuButton"
	menu_btn.custom_minimum_size = Vector2(0, BTN_H)  ## 48dp
	menu_btn.text = "MENU UTAMA"
	menu_btn.add_theme_font_size_override("font_size", 26)
	_style_button(menu_btn, C_BORDER_DANGER, C_TEXT)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_btn)

	_status = Label.new()
	_status.name = "StatusLabel"
	_status.label_settings = _ls(22, C_MUTED)  ## 11dp (minimum Material)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status)

	# --- panel konfirmasi main menu ---
	_confirm = Panel.new()
	_confirm.name = "ConfirmPanel"
	_confirm.custom_minimum_size = Vector2(400, 200)  ## 200×100dp
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.offset_left = -200
	_confirm.offset_right = 200
	_confirm.offset_top = -100
	_confirm.offset_bottom = 100
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.043, 0.063, 0.125, 0.97)
	cstyle.set_corner_radius_all(24)
	cstyle.set_border_width_all(2)
	cstyle.border_color = C_BORDER_DANGER
	cstyle.set_content_margin_all(16)
	_confirm.add_theme_stylebox_override("panel", cstyle)
	_confirm.visible = false
	add_child(_confirm)
	var cv := VBoxContainer.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.add_theme_constant_override("separation", 16)  ## 8dp — kelipatan grid Material
	_confirm.add_child(cv)
	var cq := Label.new()
	cq.label_settings = _ls(22, C_TEXT)
	cq.text = "Simpan kemajuan & keluar ke menu utama?"
	cq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(cq)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 16)
	cv.add_child(crow)
	var yes_btn := Button.new()
	yes_btn.name = "ConfirmYes"
	yes_btn.text = "YA"
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.custom_minimum_size = Vector2(0, BTN_H)
	yes_btn.add_theme_font_size_override("font_size", 24)
	_style_button(yes_btn, C_BORDER_DANGER, C_DANGER)
	yes_btn.pressed.connect(_on_confirm_yes)
	crow.add_child(yes_btn)
	var no_btn := Button.new()
	no_btn.name = "ConfirmNo"
	no_btn.text = "TIDAK"
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_btn.custom_minimum_size = Vector2(0, BTN_H)
	no_btn.add_theme_font_size_override("font_size", 24)
	_style_button(no_btn, C_BORDER, C_TEXT)
	no_btn.pressed.connect(func(): _confirm.visible = false)
	crow.add_child(no_btn)


func _style_button(btn: Button, border: Color, font: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.082, 0.16, 0.9)
	normal.set_corner_radius_all(16)
	normal.set_border_width_all(2)
	normal.border_color = border
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", _hover_style(border))
	btn.add_theme_stylebox_override("pressed", _hover_style(border))
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", font)


func _hover_style(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.12, 0.22, 0.95)
	s.set_corner_radius_all(16)
	s.set_border_width_all(2)
	s.border_color = border
	s.set_content_margin_all(8)
	return s


# ------------------------------------------------------------ public API ----
func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  ## modal blok klik ke arena
	_confirm.visible = false
	TimeSystem.pause()  ## ekonomi & wave beku saat pause
	GameManager.set_phase_direct(GameManager.Phase.PAUSE)
	QaMarkers.marker("UI", "PAUSE", {"event": "open"})


func close() -> void:
	if not visible:
		return
	_hide()
	TimeSystem.resume()
	GameManager.set_phase_direct(GameManager.Phase.COMMAND)
	QaMarkers.marker("UI", "PAUSE", {"event": "close"})


func _hide() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.visible = false


func is_open() -> bool:
	return visible


func is_paused() -> bool:
	return TimeSystem.speed <= 0.0


func _on_settings_pressed() -> void:
	## M3 #5: panel pengaturan nyata (audio/tampilan/ukuran UI/bahasa) —
	## komponen SettingsPanel yang sama dengan menu utama (satu sumber).
	var hud := get_parent()
	if hud != null and hud.has_method("open_settings"):
		_settings_panel = hud.call("get_settings_panel")
		hud.call("open_settings")
	elif _settings_panel == null:
		_settings_panel = SettingsPanel.new()
		add_child(_settings_panel)
		_settings_panel.open()
	AudioSystem.ui_click()
	QaMarkers.marker("UI", "PAUSE", {"event": "settings_open", "available": true})


func get_settings_panel() -> SettingsPanel:
	var hud := get_parent()
	if hud != null and hud.has_method("get_settings_panel"):
		return hud.call("get_settings_panel")
	return _settings_panel


func _on_main_menu_pressed() -> void:
	_confirm.visible = true


func _on_confirm_yes() -> void:
	return_to_main_menu()


## M3 #4: simpan kemajuan → navigasi NYATA ke menu utama (bukan placeholder).
## Mengembalikan true bila save berhasil (dan navigasi terjadi).
func return_to_main_menu() -> bool:
	var saved := SaveSystem.save_game()
	if not saved:
		_confirm.visible = false
		_status.text = "Gagal menyimpan — tetap di game"
		_status.label_settings.font_color = C_DANGER
		QaMarkers.marker("UI", "PAUSE", {"event": "exit_menu", "saved": false})
		return false
	_status.text = ""
	_hide()
	TimeSystem.pause()  ## tetap beku: menu utama = base idle (M3 #4)
	GameManager.return_to_menu()
	QaMarkers.marker("UI", "PAUSE", {"event": "exit_menu", "saved": true,
		"phase": GameManager.get_phase_name()})
	EventBus.main_menu_requested.emit()
	return true


# ------------------------------------------------------------- helpers ----
func _ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	ls.shadow_offset = Vector2(2, 2)
	ls.outline_size = 4
	ls.outline_color = Color(0.02, 0.03, 0.08, 0.9)
	return ls


func _close_style(border: Color) -> StyleBoxFlat:
	## Style tombol tutup berlabel (konsisten dengan card lain).
	var st := StyleBoxFlat.new()
	st.bg_color = C_CARD
	st.set_corner_radius_all(16)
	st.set_border_width_all(2)
	st.border_color = border
	st.set_content_margin_all(10)
	return st


func _load_icon(id: String) -> Texture2D:
	## icons.json embedded base64 (build wasm tanpa loader .png saat runtime).
	if _icon_cache.has(id):
		return _icon_cache[id]
	var tex: Texture2D = null
	var text := FileAccess.get_file_as_string(ICONS_JSON)
	if text == "":
		_icon_cache[id] = null
		return null
	var data: Dictionary = JSON.parse_string(text)
	var b64 := String((data.get("icons", {}) as Dictionary).get(id, ""))
	if b64 == "":
		_icon_cache[id] = null
		return null
	var raw := Marshalls.base64_to_raw(b64)
	var img := Image.new()
	if img.load_png_from_buffer(raw) == OK:
		tex = ImageTexture.create_from_image(img)
	_icon_cache[id] = tex
	return tex
