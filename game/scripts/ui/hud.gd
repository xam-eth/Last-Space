extends Control
## HUD — head-up display mobile-first landscape ANDROID (UI_UX_DESIGN.md §2–§6).
## Semua komponen adalah OVERLAY di atas gameplay arena (center arena bersih).
##
## Root viewport game ADAPTIF (project.godot viewport_width/height=0 → viewport
## = window, full screen tanpa letterbox). HUD ini = DESIGN FRAME 1280×720
## (= 640×360dp @2x = screen referensi Android 360×640dp landscape 16:9) yang
## di-scale uniform (match height) ke window aktual — ukuran fisik komponen
## sama di semua device. 1 design px = 0,5dp; semua token di bawah dalam dp
## (standar Android/Material: touch target 48dp, grid 8dp — UI_UX_DESIGN.md §6).
##
## Layout zone (design canvas 1280×720, token UI_UX_DESIGN.md §3):
##   ┌──────────────────────────────────────────────────────┐
##   │ TOP BAR: [Energy][Minerals][Fleet] | wave | menu(☰)  │  h=96, margin 24
##   │------------------------------------------------------│
##   │                GAMEPLAY ARENA (center, clear)         │
##   │  [INFO PANEL]                          ┌──────────┐  │  bottom-left info
##   │  status/log                            │ ACTION   │  │  bottom-right grid
##   │                                        │  GRID    │  │  (thumb zone kanan)
##   └──────────────────────────────────────────────────────┘
##   [TOAST: battle result / territory — top-center, auto-hide 5s]
##
## Aturan: UI read-only (nilai dari sistem, DATA_CONTRACTS.md §1); tombol
## memanggil API sistem yang sama dengan gameplay. Touch target = 48dp (96px)
## — minimum/optimal Material (UI_UX_DESIGN.md §6).

# ---- design frame (UI_UX_DESIGN.md §6: 1280×720 = 640×360dp @2x) ----
const DESIGN_W := 1280       ## lebar design canvas (px) = 640dp
const DESIGN_H := 720       ## tinggi design canvas (px) = 360dp

# ---- design tokens (UI_UX_DESIGN.md §3, dalam dp; px = dp × 2) ----
const MARGIN := 24          ## safe edge margin (12dp)
const TOP_BAR_H := 96       ## tinggi top bar (48dp)
const CHIP_W := 220         ## lebar resource chip (110dp)
const CHIP_H := 72          ## tinggi resource chip (36dp — Material chip 32–40dp)
const BTN := 96             ## tombol aksi (48dp — touch target minimum/optimal)
const GRID_GAP := 16        ## gap grid aksi (8dp — Material 8pt grid)
const GRID_COLS := 4        ## kolom action grid
const INFO_W := 420         ## lebar info panel (210dp)
const INFO_H := 140         ## tinggi info panel (70dp)
const ICONS_JSON := "res://assets/ui/icons.json"  ## runtime: ikon embedded base64 (wasm tanpa loader .png)

# palet (UI_UX_DESIGN.md §3.1)
const C_PANEL := Color(0.043, 0.063, 0.125, 0.78)
const C_BORDER := Color(0.208, 0.816, 1.0, 0.55)
const C_TEXT := Color(0.918, 0.965, 1.0, 1.0)
const C_MUTED := Color(0.62, 0.70, 0.80, 1.0)
const C_ACCENT := Color(0.208, 0.816, 1.0, 1.0)
const C_WARN := Color(1.0, 0.72, 0.30, 1.0)
const C_DANGER := Color(1.0, 0.36, 0.36, 1.0)
const C_OK := Color(0.30, 1.0, 0.53, 1.0)
const C_DIM := Color(0.45, 0.45, 0.50, 0.85)  ## unaffordable

var _top_bar: Control
var _grid: GridContainer
var _info_panel: Panel
var _energy_value: Label
var _minerals_value: Label
var _fleet_value: Label
var _energy_bar: ProgressBar
var _minerals_bar: ProgressBar
var _wave_label: Label
var _status_label: Label
var _toast_label: Label
var _toast_panel: Panel
var _action_buttons: Dictionary = {}  ## id -> {btn, label}
var _icon_cache: Dictionary = {}  ## id -> Texture2D (null jika gagal)
var _afford_timer := 0.0
var _toast_hide_at := 0  ## Time.get_ticks_msec() — auto-hide toast

# id bangunan/kapal → ikon (icon design system, UI_UX_DESIGN.md §5)
var _icon_map := {
	&"command_core": "command",
	&"energy_reactor": "reactor",
	&"mineral_extractor": "extractor",
	&"fighter_hangar": "hangar",
	&"laser_turret": "turret",
	&"shield_generator": "shield",
	&"shp_001_interceptor": "interceptor",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  ## root tidak blok arena
	_apply_design_frame()  ## design frame 1280×720, scale uniform match-height
	_build_top_bar()
	_build_action_grid()
	_build_info_panel()
	_build_toast()
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.territory_unlocked.connect(_on_territory_unlocked)
	EventBus.fleet_changed.connect(_on_fleet_changed)  ## FLEET chip update saat spawn/destroy
	get_viewport().size_changed.connect(_apply_design_frame)  ## resize/rotasi
	_refresh()
	QaMarkers.marker("HUD", "READY", {"layout": "mobile_landscape_android_adaptive"})
	await get_tree().process_frame  ## tunggu layout container selesai
	_dump_layout()


func _apply_design_frame() -> void:
	## Design frame adaptif (mobile-first Android, full screen): root viewport =
	## ukuran window aktual (project.godot viewport 0×0). HUD di-scale uniform
	## match-height dari design canvas 1280×720 (= 640×360dp) lalu di-center
	## horizontal — ukuran fisik komponen sama di semua device, arena 3D full
	## screen di belakangnya (UI_UX_DESIGN.md §6).
	var vp := get_viewport().get_visible_rect().size
	if vp.y <= 0:
		return
	var s := vp.y / float(DESIGN_H)
	set_anchors_preset(Control.PRESET_TOP_LEFT)  ## lepas full-rect anchor
	size = Vector2(DESIGN_W, DESIGN_H)
	scale = Vector2(s, s)
	position = Vector2((vp.x - DESIGN_W * s) * 0.5, 0.0)


func _dump_layout() -> void:
	## Dump rect aktual semua zona HUD (data nyata untuk verifikasi layout).
	var vp := get_viewport().get_visible_rect().size
	var parts: Array[String] = []
	parts.append("viewport[%.0fx%.0f]" % [vp.x, vp.y])
	parts.append("scale[%.3f]" % scale.x)
	for c in get_children():
		if c is Control:
			var r := (c as Control).get_global_rect()
			parts.append("%s[%.0f,%.0f %.0fx%.0f]" % [c.name, r.position.x, r.position.y, r.size.x, r.size.y])
	if _grid != null:
		var cells: Array[String] = []
		for i in _grid.get_child_count():
			var cell := _grid.get_child(i) as Control
			var r := cell.get_global_rect()
			cells.append("c%d[%.0f,%.0f %.0fx%.0f]" % [i, r.position.x, r.position.y, r.size.x, r.size.y])
		parts.append("cells:" + " ".join(cells))
	QaMarkers.marker("HUD", "LAYOUT", {"zones": " ".join(parts)})


# ------------------------------------------------------------ top bar ----
func _build_top_bar() -> void:
	var bar := Control.new()
	bar.name = "TopBar"
	_top_bar = bar
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = 12
	bar.offset_bottom = 12 + TOP_BAR_H
	add_child(bar)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", GRID_GAP)
	bar.add_child(box)

	# kiri: resource chips (ikon + label + nilai aktual + bar)
	var chips := HBoxContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", GRID_GAP)
	box.add_child(chips)
	var chip_e := _make_chip("energy", "ENERGY", C_WARN)
	chips.add_child(chip_e["chip"])
	_energy_value = chip_e["value"]
	_energy_bar = chip_e["bar"]
	var chip_m := _make_chip("minerals", "MINERALS", Color(0.78, 0.71, 0.54, 1.0))
	chips.add_child(chip_m["chip"])
	_minerals_value = chip_m["value"]
	_minerals_bar = chip_m["bar"]
	var chip_f := _make_chip("fleet", "FLEET", C_ACCENT)
	chips.add_child(chip_f["chip"])
	_fleet_value = chip_f["value"]

	# tengah: indikator wave (ancaman) — center top = fokus informasi
	_wave_label = Label.new()
	_wave_label.label_settings = _ls(24, C_TEXT)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.text = "ARENA CLEAR"
	box.add_child(_wave_label)

	# kanan: tombol menu (ikon)
	var menu_btn := TextureButton.new()
	menu_btn.name = "MenuButton"
	menu_btn.custom_minimum_size = Vector2(80, 80)
	menu_btn.ignore_texture_size = true  ## min size = 96 (bukan ukuran tekstur 256)
	menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_btn.texture_normal = _load_icon("menu")
	menu_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	menu_btn.pressed.connect(_on_menu_pressed)
	box.add_child(menu_btn)


func _make_chip(icon_id: String, label_text: String, accent: Color) -> Dictionary:
	## Resource chip: panel + [ikon | label/value] + progress bar (opsional).
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(CHIP_W, CHIP_H)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER  ## tinggi tetap 96 di bar 128
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(10)
	chip.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	chip.add_child(vbox)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.ignore_texture_size = true  ## min size = 40 (bukan ukuran tekstur 256)
	icon.texture = _load_icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var cap := Label.new()
	cap.label_settings = _ls(18, C_MUTED)
	cap.text = label_text
	texts.add_child(cap)
	var value := Label.new()
	value.label_settings = _ls(28, C_TEXT)
	texts.add_child(value)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = 100.0
	bar.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg_style.set_corner_radius_all(5)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = accent
	fill_style.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("bg", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	vbox.add_child(bar)
	return {"chip": chip, "value": value, "bar": bar}


# -------------------------------------------------------- action grid ----
func _build_action_grid() -> void:
	## Thumb zone kanan-bawah: grid ikon aksi (build + kapal).
	var grid := GridContainer.new()
	grid.name = "ActionGrid"
	_grid = grid
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var grid_w := GRID_COLS * BTN + (GRID_COLS - 1) * GRID_GAP
	var rows := 2
	var grid_h := rows * BTN + (rows - 1) * GRID_GAP  ## cell = BTN (ikon only, 48dp)
	grid.offset_left = -(grid_w + MARGIN)
	grid.offset_top = -(grid_h + MARGIN)
	grid.offset_right = -MARGIN
	grid.offset_bottom = -MARGIN
	add_child(grid)

	var pr := SystemRefs.progression_system()
	var actions: Array = []
	if pr != null:
		for id in pr.unlocked:
			var def := GameData.get_building_def(id)
			if def != null:
				actions.append(id)
	actions.append(&"shp_001_interceptor")  ## aksi kapal selalu ada

	for id in actions:
		var cell := Control.new()  ## cell = BTN×BTN, ikon only (48dp) — lihat UI_UX_DESIGN.md §4
		cell.custom_minimum_size = Vector2(BTN, BTN)
		var btn := TextureButton.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.ignore_texture_size = true  ## min size = 96 (bukan ukuran tekstur 256)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_normal = _load_icon(_icon_for(id))
		var def := GameData.get_building_def(id)
		if def != null:
			btn.tooltip_text = "%s — E%d M%d — tap untuk membangun" % [def.display_name,
				int(def.base_cost.get("energy", 0)), int(def.base_cost.get("minerals", 0))]
			btn.pressed.connect(_on_build_pressed.bind(id))
		else:
			btn.tooltip_text = "Interceptor — tap untuk membangun"
			btn.pressed.connect(_on_ship_pressed)
		cell.add_child(btn)
		grid.add_child(cell)
		_action_buttons[id] = {"btn": btn}


# -------------------------------------------------------- info panel ----
func _build_info_panel() -> void:
	## Thumb zone kiri-bawah: panel info — status + hasil (read-only).
	var panel := Panel.new()
	panel.name = "InfoPanel"
	_info_panel = panel
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = MARGIN
	panel.offset_right = MARGIN + INFO_W
	panel.offset_top = -(INFO_H + MARGIN)
	panel.offset_bottom = -MARGIN
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	_status_label = Label.new()
	_status_label.label_settings = _ls(24, C_TEXT)
	_status_label.text = "Command online."
	vbox.add_child(_status_label)
	var result := Label.new()
	result.label_settings = _ls(26, C_ACCENT)
	result.name = "ResultLabel"
	vbox.add_child(result)


# ------------------------------------------------------------- toast ----
func _build_toast() -> void:
	## Toast top-center (di bawah top bar): hasil battle / territory.
	_toast_panel = Panel.new()
	_toast_panel.name = "Toast"
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_left = -280
	_toast_panel.offset_right = 280
	_toast_panel.offset_top = 12 + TOP_BAR_H + 12
	_toast_panel.offset_bottom = 12 + TOP_BAR_H + 12 + 56
	_toast_panel.custom_minimum_size = Vector2(560, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.063, 0.125, 0.92)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = C_ACCENT
	style.set_content_margin_all(10)
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.label_settings = _ls(26, C_TEXT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_panel.add_child(_toast_label)


# ------------------------------------------------------------ helpers ----
func _ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	ls.shadow_offset = Vector2(2, 2)
	ls.outline_size = 4
	ls.outline_color = Color(0.02, 0.03, 0.08, 0.9)
	return ls


func _icon_for(id: StringName) -> String:
	return _icon_map.get(id, "command")


func _load_icon(id: String) -> Texture2D:
	## Load ikon dari icons.json (embedded base64 PNG) — build wasm tidak
	## punya loader .png saat runtime; decode via Image.load_png_from_buffer.
	if _icon_cache.has(id):
		return _icon_cache[id]
	var tex: Texture2D = null
	var text := FileAccess.get_file_as_string(ICONS_JSON)
	if text == "":
		push_warning("HUD: tidak bisa baca %s" % ICONS_JSON)
		_icon_cache[id] = null
		return null
	var data: Dictionary = JSON.parse_string(text)
	if data == null:
		push_warning("HUD: icons.json invalid")
		_icon_cache[id] = null
		return null
	var b64 := String((data.get("icons", {}) as Dictionary).get(id, ""))
	if b64 == "":
		push_warning("HUD: ikon tidak ada di icons.json: %s" % id)
		_icon_cache[id] = null
		return null
	var raw := Marshalls.base64_to_raw(b64)
	var img := Image.new()
	var err := img.load_png_from_buffer(raw)
	if err == OK:
		tex = ImageTexture.create_from_image(img)
	else:
		push_warning("HUD: decode ikon %s gagal (err=%d)" % [id, err])
	_icon_cache[id] = tex
	return tex




func _refresh() -> void:
	# nilai aktual dari sistem (read-only)
	var e := Economy.get_amount(&"energy")
	var ec := Economy.get_cap(&"energy")
	_energy_value.text = "%d / %d" % [e, ec]
	_energy_bar.value = (100.0 * e / ec) if ec > 0 else 0.0
	var m := Economy.get_amount(&"minerals")
	var mc := Economy.get_cap(&"minerals")
	_minerals_value.text = "%d / %d" % [m, mc]
	_minerals_bar.value = (100.0 * m / mc) if mc > 0 else 0.0
	var fs := SystemRefs.fleet_system()
	_fleet_value.text = "%d ships" % (fs.alive_count() if fs != null else 0)
	_refresh_affordability()


func _refresh_affordability() -> void:
	for id in _action_buttons.keys():
		var entry: Dictionary = _action_buttons[id]
		var btn := entry["btn"] as TextureButton
		var def := GameData.get_building_def(id)
		var affordable := true
		if def != null:
			affordable = Economy.can_afford(def.base_cost)
		else:
			var ship_def := GameData.get_ship_def(id)
			if ship_def != null:
				affordable = Economy.can_afford(ship_def.cost)
		if affordable:
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = C_DIM


func _show_toast(text: String, color: Color) -> void:
	_toast_label.text = text
	_toast_label.label_settings.font_color = color
	_toast_panel.visible = true
	# auto-hide 5 detik (toast — bukan informasi permanen); token waktu
	# mencegah toast lama menyembunyikan toast baru lebih awal.
	_toast_hide_at = Time.get_ticks_msec() + 5000


func _process(delta: float) -> void:
	# refresh affordability berkala (data berubah di luar event resource)
	_afford_timer += delta
	if _afford_timer >= 0.5:
		_afford_timer = 0.0
		_refresh_affordability()
	# auto-hide toast
	if _toast_panel.visible and Time.get_ticks_msec() >= _toast_hide_at:
		_toast_panel.visible = false


# ------------------------------------------------------------ events ----
func _on_resource_changed(_res, _old, _new, _delta) -> void:
	_refresh()


func _on_fleet_changed() -> void:
	_refresh()  ## FLEET chip = jumlah kapal aktual (sempat stale — ditemukan via stress scene)


func _on_build_pressed(def_id: StringName) -> void:
	var bs := SystemRefs.building_system()
	var ps := SystemRefs.production_system()
	if bs == null or ps == null:
		return
	var def := GameData.get_building_def(def_id)
	if def == null:
		return
	var pos := bs.next_free_position(def.footprint)
	if ps.enqueue_construction(def_id, pos):
		_status_label.text = "Building %s..." % def.display_name
	else:
		_status_label.text = "Cannot afford %s" % def.display_name


func _on_ship_pressed() -> void:
	var ps := SystemRefs.production_system()
	if ps == null:
		return
	if ps.enqueue_ship(&"shp_001_interceptor"):
		_status_label.text = "Building Interceptor..."
	else:
		_status_label.text = "Cannot build Interceptor (need hangar + funds)"


func _on_menu_pressed() -> void:
	# Menu belum diimplementasi (M2) — jujur, tidak fake.
	_status_label.text = "Menu — coming soon (M2)"


func _on_wave_incoming(wave_id: StringName, eta: int) -> void:
	_wave_label.text = "WAVE %s — %d ticks" % [wave_id, eta]
	_wave_label.label_settings.font_color = C_DANGER
	_status_label.text = "WARNING: alien wave %s incoming in %d ticks!" % [wave_id, eta]


func _on_combat_finished(result: BattleResult) -> void:
	var color := C_OK if result.winner == "defender" else C_DANGER
	_show_toast("BATTLE: %s WON (%d TICKS)" % [result.winner.to_upper(), result.duration_ticks], color)


func _on_territory_unlocked(sector_id: StringName) -> void:
	_show_toast("TERRITORY UNLOCKED: %s" % sector_id.to_upper(), C_ACCENT)
	_status_label.text = "Territory unlocked: %s" % sector_id
