extends Control
## PauseMenu — modal pause (GAMEPLAY_FLOW.md §3 Frame 8, M3 #3).
## Tombol: RESUME (56dp), SETTINGS (48dp), MAIN MENU (48dp + konfirmasi).
##
## Ukuran (design canvas, UI_UX_DESIGN.md §3): modal 480×360 (240×180dp),
## anchor center semua aspek; tombol besar tinggi 56dp/48dp (UI_UX_DESIGN §4).
##
## Aturan: saat pause, TimeSystem.pause (ekonomi/wave beku) + GameManager
## phase PAUSE; resume → TimeSystem.resume + phase COMMAND. MAIN MENU
## konfirmasi → SaveSystem.save_game (progress tersimpan) — scene main menu
## belum ada (M3 #4), dilaporkan jujur via status (tidak fake).

const MODAL_W := 480   ## 240dp
const MODAL_H := 360   ## 180dp
const TITLE_H := 64    ## 32dp
const BTN_BIG_H := 112 ## 56dp (tombol utama)
const BTN_H := 96      ## 48dp
const ICONS_JSON := "res://assets/ui/icons.json"

const C_PANEL := Color(0.043, 0.063, 0.125, 0.92)
const C_BORDER := Color(0.208, 0.816, 1.0, 0.55)
const C_BORDER_DANGER := Color(1.0, 0.36, 0.36, 0.6)
const C_TEXT := Color(0.918, 0.965, 1.0, 1.0)
const C_MUTED := Color(0.62, 0.70, 0.80, 1.0)
const C_ACCENT := Color(0.208, 0.816, 1.0, 1.0)
const C_DANGER := Color(1.0, 0.36, 0.36, 1.0)

var _dim: ColorRect
var _modal: Panel
var _status: Label
var _confirm: Panel
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
	var close_btn := TextureButton.new()
	close_btn.name = "CloseButton"
	close_btn.custom_minimum_size = Vector2(96, 96)  ## 48dp — touch target minimum Material
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.texture_normal = _load_icon("close")
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
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.visible = false
	TimeSystem.resume()
	GameManager.set_phase_direct(GameManager.Phase.COMMAND)
	QaMarkers.marker("UI", "PAUSE", {"event": "close"})


func is_open() -> bool:
	return visible


func is_paused() -> bool:
	return TimeSystem.speed <= 0.0


func _on_settings_pressed() -> void:
	## Settings = M3 #5 (belum ada) — jujur, tidak fake.
	_status.text = "Pengaturan — segera hadir (M3 #5)"
	_status.label_settings.font_color = C_MUTED


func _on_main_menu_pressed() -> void:
	_confirm.visible = true


func _on_confirm_yes() -> void:
	## Save progress lalu lapor jujur: scene main menu belum ada (M3 #4).
	var saved := SaveSystem.save_game()
	if saved:
		_status.text = "Kemajuan tersimpan. Menu utama belum tersedia (M3 #4)."
		_status.label_settings.font_color = C_ACCENT
	else:
		_status.text = "Gagal menyimpan — tetap di game."
		_status.label_settings.font_color = C_DANGER
	_confirm.visible = false
	QaMarkers.marker("UI", "PAUSE", {"event": "save_exit", "saved": saved})


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
