extends Control
## HUD — head-up display mobile-first landscape ANDROID (UI_UX_DESIGN.md §2–§6).
## Semua komponen adalah OVERLAY di atas gameplay arena (center arena bersih).
##
## Root viewport game ADAPTIF (project.godot viewport_width/height=0 → viewport
## = window, full screen tanpa letterbox; stretch aspect=expand). HUD = FULL
## RECT (isi penuh window, semua aspek 16:9/19.5:9/20:9) dengan design canvas
## 1280×720 (= 640×360dp @2x = screen referensi Android 360×640dp landscape
## 16:9) — scale uniform match-height (ukuran fisik komponen sama di semua
## device), zona di-anchor ke edge window. 1 design px = 0,5dp; semua token
## di bawah dalam dp (standar Android/Material: touch target 48dp, grid 8dp —
## UI_UX_DESIGN.md §6).
##
## Layout zone (design canvas 1280×720, token UI_UX_DESIGN.md §3):
##   ┌──────────────────────────────────────────────────────┐
##   │ TOP BAR: [Energy][Minerals][Fleet] | wave | menu(☰)  │  h=96, margin 24
##   │------------------------------------------------------│
##   │  [QUEST PANEL]                                        │
##   │  objektif aktif        GAMEPLAY ARENA (center)       │
##   │  (kiri tengah)                          ┌──────────┐  │
##   │  [INFO PANEL]                          │ ACTION   │  │  bottom-left info
##   │  status/log            [SELECTION]     │ build    │  │  bottom-center: klik
##   │                        (bawah tengah)  │ fleet    │  │  bangunan → upgrade
##   │                                        └──────────┘  │  kanan-bawah: 2 tombol
##   └──────────────────────────────────────────────────────┘
##   [TOAST: battle result / territory / quest — top-center, auto-hide 5s]
##   [BUILD MENU + SHIP MENU: modal tengah — pola Doomsday,
##    GAMEPLAY_FLOW.md Frame 5/6]
##
## Aturan: UI read-only (nilai dari sistem, DATA_CONTRACTS.md §1); tombol
## memanggil API sistem yang sama dengan gameplay. Touch target = 48dp (96px)
## — minimum/optimal Material (UI_UX_DESIGN.md §6).

# ---- design frame (UI_UX_DESIGN.md §6: 1280×720 = 640×360dp @2x) ----
const DESIGN_W := 1280       ## lebar design canvas (px) = 640dp
const DESIGN_H := 720       ## tinggi design canvas (px) = 360dp

# ---- design tokens (UI_UX_DESIGN.md §3, dalam dp; px = dp × 2) ----
const MARGIN := 32          ## safe edge margin (16dp — standar Material mobile edge margin)
const TOP_BAR_H := 96       ## tinggi top bar (48dp)
const CHIP_W := 236         ## lebar resource chip (118dp)
const CHIP_H := 96          ## tinggi resource chip (48dp — sama dengan bar & touch target)
const BTN := 96             ## tombol aksi (48dp — touch target minimum/optimal)
const GRID_GAP := 16        ## gap grid aksi (8dp — Material 8pt grid)
const GRID_COLS := 4        ## kolom action grid
const INFO_W := 420         ## lebar info panel (210dp)
const INFO_H := 140         ## tinggi info panel (70dp)
const QUEST_W := 440        ## lebar quest panel (220dp)
const QUEST_H := 288        ## tinggi quest panel (144dp — 4 objektif, teks standar Material)
const SEL_W := 560          ## lebar selection panel (280dp)
const SEL_H := 140          ## tinggi selection panel (70dp)
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
var _build_menu: Control          ## modal build (GAMEPLAY_FLOW Frame 5)
var _ship_menu: Control           ## modal fleet/produksi kapal (Frame 6, M3 #2)
var _pause_menu: Control          ## modal pause (Frame 8, M3 #3)
var _quest_rows: VBoxContainer     ## quest panel kiri tengah
var _sel_panel: Panel              ## selection panel bawah tengah
var _sel_name: Label
var _sel_level: Label
var _sel_hp: ProgressBar
var _sel_upgrade_btn: TextureButton
var _sel_upgrade_cost: Dictionary = {}
var _selected_instance: String = ""
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
	_apply_design_frame()  ## full-rect + scale match-height (isi penuh semua aspek)
	_build_top_bar()
	_build_action_grid()
	_build_info_panel()
	_build_quest_panel()   ## kiri tengah (pola Doomsday F3/F8)
	_build_selection_panel()  ## bawah tengah (klik bangunan → upgrade, Frame 4)
	_build_build_menu()    ## modal (Frame 5)
	_build_ship_menu()     ## modal fleet (Frame 6, M3 #2)
	_build_pause_menu()    ## modal pause (Frame 8, M3 #3)
	_build_toast()
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.territory_unlocked.connect(_on_territory_unlocked)
	EventBus.fleet_changed.connect(_on_fleet_changed)  ## FLEET chip update saat spawn/destroy
	EventBus.quest_progress.connect(_on_quest_progress)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.building_upgraded.connect(_on_building_state_changed)
	EventBus.building_damaged.connect(_on_building_state_changed)
	EventBus.building_repaired.connect(_on_building_state_changed)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.production_completed.connect(_on_production_completed)
	get_viewport().size_changed.connect(_apply_design_frame)  ## resize/rotasi
	_refresh()
	_refresh_quest()
	QaMarkers.marker("HUD", "READY", {"layout": "mobile_landscape_android_adaptive"})
	await get_tree().process_frame  ## tunggu layout container selesai
	_dump_layout()


func _apply_design_frame() -> void:
	## HUD FULL-RECT — isi penuh window di SEMUA aspek layar (16:9, 19.5:9,
	## 20:9 — mayoritas Android modern BUKAN 16:9): root = full window, scale
	## uniform match-height dari design tinggi 720 → ukuran fisik komponen
	## TETAP (ikon 48dp, margin 12dp); zona di-anchor ke edge window
	## (TopBar kiri/kanan, ActionGrid kanan-bawah, InfoPanel kiri-bawah) →
	## tidak ada black bars / tidak ada center kosong (koreksi fatal dari
	## feedback human 2026-10-11: sebelumnya design-frame center → HUD hanya
	## 1920px di tengah layar 2340px, kiri/kanan kosong pekat).
	var vp := get_viewport().get_visible_rect().size
	if vp.y <= 0:
		return
	## STANDAR (bukan asumsi): di Android/browser modern 1 CSS px = 1 dp
	## (spec Android density-independent), dan device px = CSS px ×
	## devicePixelRatio. Maka agar komponen berukuran TETAP dalam dp
	## (tombol 48dp, margin 16dp) di semua device/density:
	##     scale (design px → device px) = devicePixelRatio / 2
	## karena design px = dp × 2 (design canvas 1280×720 = 640×360dp, 16:9).
	## Device 1080p dpr3 (xxhdpi): 96 × 1,5 = 144 px = 48dp. Tablet/desktop
	## besar (dp tinggi > 360) TIDAK ikut membesar — ini koreksi "komponen
	## terlalu besar di layar besar" (Material: ukuran = dp, bukan persen).
	var dpr := _device_pixel_ratio()
	var s := clampf(dpr / 2.0, 0.5, 3.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	size = vp / s  ## design space; di layar = size × scale = vp (full window)
	scale = Vector2(s, s)
	position = Vector2.ZERO


func _device_pixel_ratio() -> float:
	## device px per CSS px (≈ dp). Web: window.devicePixelRatio (data nyata
	## browser). Native/desktop: dpi layar / 160 (baseline mdpi). Fallback 2.0
	## = referensi xhdpi (design px = dp × 2) supaya di lingkungan uji tanpa
	## info density, ukuran tetap standar (bukan menebak dari tinggi window).
	## Web (VERIFIED dari source Godot 4.7.2 platform/web/js/libs/
	## library_godot_display.js:238): godot_js_display_pixel_ratio_get()
	## mengembalikan window.devicePixelRatio → DisplayServer.screen_get_scale()
	## = device pixel ratio (data nyata browser, bukan asumsi).
	## Catatan jujur: JavaScriptBridge.eval("window.LS_DPR") mengembalikan null
	## di build ini (evidence jsDpr[<null>]) → handshake JS tidak dipakai;
	## nilai LS_DPR tetap dicetak halaman sebagai bukti device class.
	var sc := DisplayServer.screen_get_scale()
	if sc > 0.0:
		return clampf(sc, 1.0, 4.0)
	## Fallback: dpi/96 (web: dpi = devicePixelRatio × 96, source baris 354).
	var dpi := DisplayServer.screen_get_dpi()
	if dpi > 0:
		return clampf(float(dpi) / 96.0, 1.0, 4.0)
	return 2.0  ## referensi xhdpi (design px = dp × 2) bila density tak diketahui


func _dump_layout() -> void:
	## Dump rect aktual semua zona HUD (data nyata untuk verifikasi layout).
	var vp := get_viewport().get_visible_rect().size
	var parts: Array[String] = []
	parts.append("viewport[%.0fx%.0f]" % [vp.x, vp.y])
	parts.append("dpr[%.2f]" % _device_pixel_ratio())
	if OS.has_feature("web"):
		parts.append("jsDpr[%s]" % str(JavaScriptBridge.eval("window.LS_DPR", true)))
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
	bar.offset_top = MARGIN      ## 16dp — aman untuk notch/status bar (safe area)
	bar.offset_bottom = MARGIN + TOP_BAR_H
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
	var chip_e := _make_chip("energy", "ENERGI", C_WARN)
	chips.add_child(chip_e["chip"])
	_energy_value = chip_e["value"]
	_energy_bar = chip_e["bar"]
	var chip_m := _make_chip("minerals", "MINERAL", Color(0.78, 0.71, 0.54, 1.0))
	chips.add_child(chip_m["chip"])
	_minerals_value = chip_m["value"]
	_minerals_bar = chip_m["bar"]
	var chip_f := _make_chip("fleet", "ARMADA", C_ACCENT)
	chips.add_child(chip_f["chip"])
	_fleet_value = chip_f["value"]

	# tengah: indikator wave (ancaman) — center top = fokus informasi
	_wave_label = Label.new()
	_wave_label.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.text = "ARENA BERSIH"
	box.add_child(_wave_label)

	# kanan: tombol menu (ikon)
	var menu_btn := TextureButton.new()
	menu_btn.name = "MenuButton"
	menu_btn.custom_minimum_size = Vector2(96, 96)  ## 48dp — touch target minimum Material
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
	vbox.add_theme_constant_override("separation", 8)  ## 4dp — kelipatan grid Material
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
	cap.label_settings = _ls(22, C_MUTED)  ## 11dp labelSmall (minimum Material)
	cap.text = label_text
	texts.add_child(cap)
	var value := Label.new()
	value.label_settings = _ls(32, C_TEXT)  ## 16dp titleMedium
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

	## M3 #1: aksi = BUILD (buka modal menu konstruksi, Frame 5) + produksi kapal.
	## Bangun/upgrade bangunan individual: via build menu (baru) & klik bangunan
	## di arena (selection panel, Frame 4) — bukan tombol langsung per bangunan.
	var actions: Array = [&"build", &"shp_001_interceptor"]

	for id in actions:
		var cell := Control.new()  ## cell = BTN×BTN, ikon only (48dp) — lihat UI_UX_DESIGN.md §4
		cell.custom_minimum_size = Vector2(BTN, BTN)
		var btn := TextureButton.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.ignore_texture_size = true  ## min size = 96 (bukan ukuran tekstur 256)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		if id == &"build":
			btn.texture_normal = _load_icon("build")
			btn.tooltip_text = "Bangun — buka menu konstruksi"
			btn.pressed.connect(open_build_menu)
		else:
			btn.texture_normal = _load_icon(_icon_for(id))
			btn.tooltip_text = "Armada — buka menu produksi kapal"
			btn.pressed.connect(open_ship_menu)
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
	_status_label.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
	_status_label.text = "Pusat komando aktif."
	vbox.add_child(_status_label)
	var result := Label.new()
	result.label_settings = _ls(28, C_ACCENT)  ## 14dp bodyMedium
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
	_toast_label.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
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
	_fleet_value.text = "%d kapal" % (fs.alive_count() if fs != null else 0)
	_refresh_affordability()


func _refresh_affordability() -> void:
	for id in _action_buttons.keys():
		var entry: Dictionary = _action_buttons[id]
		var btn := entry["btn"] as TextureButton
		if id == &"build" or id == &"shp_001_interceptor":
			continue  ## tombol menu selalu aktif
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
		_refresh_selection()
	# auto-hide toast
	if _toast_panel.visible and Time.get_ticks_msec() >= _toast_hide_at:
		_toast_panel.visible = false


# ------------------------------------------------------------ events ----
func _on_resource_changed(_res, _old, _new, _delta) -> void:
	_refresh()


func _on_fleet_changed() -> void:
	_refresh()  ## FLEET chip = jumlah kapal aktual (sempat stale — ditemukan via stress scene)


# -------------------------------------------------------- build menu ----
func _build_build_menu() -> void:
	## Modal build (GAMEPLAY_FLOW.md §3 Frame 5) — pola Doomsday BAG.
	var bm: Control = load("res://scripts/ui/build_menu.gd").new()
	bm.name = "BuildMenu"
	bm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bm)
	_build_menu = bm


func open_build_menu() -> void:
	if _build_menu != null:
		_build_menu.call("open")


func close_build_menu() -> void:
	if _build_menu != null:
		_build_menu.call("close")


func is_build_menu_open() -> bool:
	return _build_menu != null and _build_menu.visible


func get_build_menu() -> Control:
	return _build_menu


# -------------------------------------------------------- quest panel ----
func _build_quest_panel() -> void:
	## Panel kiri TENGAH: daftar objektif aktif + progress (pola Doomsday F3/F8,
	## di atas info panel kiri bawah). Read-only — dengar QuestTracker via EventBus.
	var panel := Panel.new()
	panel.name = "QuestPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = MARGIN
	panel.offset_right = MARGIN + QUEST_W
	panel.offset_top = -(INFO_H + MARGIN + GRID_GAP + QUEST_H)
	panel.offset_bottom = -(INFO_H + MARGIN + GRID_GAP)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)  ## 4dp — kelipatan grid Material
	panel.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var qicon := TextureRect.new()
	qicon.custom_minimum_size = Vector2(32, 32)
	qicon.ignore_texture_size = true
	qicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qicon.texture = _load_icon("quest")
	qicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(qicon)
	var qtitle := Label.new()
	qtitle.label_settings = _ls(24, C_ACCENT)  ## 12dp labelMedium
	qtitle.text = "OBJEKTIF"
	title_row.add_child(qtitle)
	_quest_rows = VBoxContainer.new()
	_quest_rows.add_theme_constant_override("separation", 8)  ## 4dp — kelipatan grid
	vbox.add_child(_quest_rows)


func _refresh_quest() -> void:
	if _quest_rows == null:
		return
	for c in _quest_rows.get_children():
		c.queue_free()
	var qt := SystemRefs.quest_tracker()
	if qt == null:
		return
	for q in qt.get_all():
		var d: Dictionary = q
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quest_rows.add_child(row)
		var mark := Label.new()
		mark.label_settings = _ls(24, C_OK if d["done"] else C_MUTED)  ## 12dp
		mark.text = "[x]" if d["done"] else "[ ]"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texts)
		var nm := Label.new()
		nm.label_settings = _ls(24, C_OK if d["done"] else C_TEXT)  ## 12dp
		nm.text = d["title"]
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(nm)
		var prog_row := HBoxContainer.new()
		prog_row.add_theme_constant_override("separation", 8)
		prog_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(prog_row)
		var pct := Label.new()
		pct.label_settings = _ls(22, C_MUTED)  ## 11dp labelSmall (minimum Material)
		pct.text = "%d/%d" % [int(d["current"]), int(d["target"])]
		pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog_row.add_child(pct)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = maxi(1, int(d["target"]))
		bar.value = int(d["current"])
		bar.show_percentage = false
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
		bg_style.set_corner_radius_all(5)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = C_OK if d["done"] else C_ACCENT
		fill_style.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("bg", bg_style)
		bar.add_theme_stylebox_override("fill", fill_style)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog_row.add_child(bar)


# ---------------------------------------------------- selection panel ----
func _build_selection_panel() -> void:
	## Panel BAWAH TENGAH: bangunan terpilih di arena 3D — nama + level + HP +
	## tombol UPGRADE (aksi konteks, pola Doomsday F4: Info/Level Up).
	var panel := Panel.new()
	panel.name = "SelectionPanel"
	_sel_panel = panel
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -SEL_W / 2.0
	panel.offset_right = SEL_W / 2.0
	panel.offset_top = -(SEL_H + MARGIN)
	panel.offset_bottom = -MARGIN
	panel.custom_minimum_size = Vector2(SEL_W, SEL_H)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	add_child(panel)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 8)  ## 4dp — kelipatan grid
	row.add_child(texts)
	_sel_name = Label.new()
	_sel_name.label_settings = _ls(30, C_TEXT)  ## 15dp titleMedium
	texts.add_child(_sel_name)
	_sel_level = Label.new()
	_sel_level.label_settings = _ls(22, C_MUTED)  ## 11dp labelSmall (minimum Material)
	texts.add_child(_sel_level)
	_sel_hp = ProgressBar.new()
	_sel_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sel_hp.custom_minimum_size = Vector2(0, 12)
	_sel_hp.max_value = 100.0
	_sel_hp.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg_style.set_corner_radius_all(5)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = C_OK
	fill_style.set_corner_radius_all(5)
	_sel_hp.add_theme_stylebox_override("bg", bg_style)
	_sel_hp.add_theme_stylebox_override("fill", fill_style)
	row.add_child(_sel_hp)
	_sel_upgrade_btn = TextureButton.new()
	_sel_upgrade_btn.name = "UpgradeButton"
	_sel_upgrade_btn.custom_minimum_size = Vector2(BTN, BTN)  ## 48dp
	_sel_upgrade_btn.ignore_texture_size = true
	_sel_upgrade_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_sel_upgrade_btn.texture_normal = _load_icon("upgrade")
	_sel_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	row.add_child(_sel_upgrade_btn)


func select_building(instance_id: String) -> void:
	## Dipanggil base_scene saat pemain klik bangunan di arena 3D.
	var bs := SystemRefs.building_system()
	if bs == null:
		return
	var b := bs.get_building(instance_id)
	if b == null or b.is_destroyed():
		return
	_selected_instance = instance_id
	_sel_panel.visible = true
	_refresh_selection()
	QaMarkers.marker("UI", "SELECT", {"instance": instance_id, "id": b.def.id, "level": b.level})


func deselect_building() -> void:
	_selected_instance = ""
	if _sel_panel != null:
		_sel_panel.visible = false


func get_selected_instance() -> String:
	return _selected_instance


func _refresh_selection() -> void:
	if _sel_panel == null or not _sel_panel.visible:
		return
	var bs := SystemRefs.building_system()
	if bs == null:
		return
	var b := bs.get_building(_selected_instance)
	if b == null:
		deselect_building()
		return
	_sel_name.text = b.def.display_name
	_sel_level.text = "Lv %d — %s" % [b.level, b.def.id]
	var max_hp := b.get_max_hp()
	_sel_hp.value = (100.0 * b.hp / max_hp) if max_hp > 0 else 0.0
	if b.level >= b.def.max_level:
		_sel_upgrade_cost = {}
		_sel_upgrade_btn.disabled = true
		_sel_upgrade_btn.modulate = C_DIM
		_sel_upgrade_btn.tooltip_text = "LEVEL MAKS"
	else:
		_sel_upgrade_cost = b.def.get_cost_for_level(b.level + 1)
		var affordable := Economy.can_afford(_sel_upgrade_cost)
		_sel_upgrade_btn.disabled = not affordable
		_sel_upgrade_btn.modulate = Color(1, 1, 1, 1) if affordable else C_DIM
		_sel_upgrade_btn.tooltip_text = "Upgrade ke Lv %d — %s" % [b.level + 1, _cost_text(_sel_upgrade_cost)]


func _on_upgrade_pressed() -> void:
	var bs := SystemRefs.building_system()
	if bs == null or _selected_instance == "":
		return
	if bs.try_upgrade(_selected_instance):
		_status_label.text = "Ditingkatkan: %s" % _sel_name.text
	else:
		_status_label.text = "Sumber daya tidak cukup"
	_refresh_selection()


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if int(cost.get("energy", 0)) > 0:
		parts.append("E%d" % int(cost.get("energy", 0)))
	if int(cost.get("minerals", 0)) > 0:
		parts.append("M%d" % int(cost.get("minerals", 0)))
	return " ".join(parts) if not parts.is_empty() else "GRATIS"


func _on_building_state_changed(instance_id: String, _a = null, _b = null) -> void:
	if instance_id == _selected_instance:
		_refresh_selection()


func _on_building_destroyed(instance_id: String) -> void:
	if instance_id == _selected_instance:
		deselect_building()


func _on_production_completed(kind: String, id: StringName, amount: int) -> void:
	if kind == "construction":
		_status_label.text = "Pembangunan selesai: %s" % id
		_refresh_quest()


# ---------------------------------------------------------- ship menu ----
func _build_ship_menu() -> void:
	## Modal fleet/produksi kapal (GAMEPLAY_FLOW.md §3 Frame 6, M3 #2).
	var sm: Control = load("res://scripts/ui/ship_menu.gd").new()
	sm.name = "ShipMenu"
	sm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sm)
	_ship_menu = sm


func open_ship_menu() -> void:
	if _ship_menu != null:
		_ship_menu.call("open")


func close_ship_menu() -> void:
	if _ship_menu != null:
		_ship_menu.call("close")


func is_ship_menu_open() -> bool:
	return _ship_menu != null and _ship_menu.visible


func get_ship_menu() -> Control:
	return _ship_menu


func _on_menu_pressed() -> void:
	## Tombol menu (☰) kanan atas → pause menu (GAMEPLAY_FLOW.md Frame 8, M3 #3).
	open_pause_menu()


# ---------------------------------------------------------- pause menu ----
func _build_pause_menu() -> void:
	## Modal pause (GAMEPLAY_FLOW.md §3 Frame 8, M3 #3): Resume/Settings/
	## Main Menu. TimeSystem beku saat terbuka.
	var pm: Control = load("res://scripts/ui/pause_menu.gd").new()
	pm.name = "PauseMenu"
	pm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pm)
	_pause_menu = pm


func open_pause_menu() -> void:
	if _pause_menu != null:
		_pause_menu.call("open")


func close_pause_menu() -> void:
	if _pause_menu != null:
		_pause_menu.call("close")


func is_pause_menu_open() -> bool:
	return _pause_menu != null and _pause_menu.visible


func get_pause_menu() -> Control:
	return _pause_menu


func _on_wave_incoming(wave_id: StringName, eta: int) -> void:
	_wave_label.text = "WAVE %s — %d detik" % [wave_id, eta]
	_wave_label.label_settings.font_color = C_DANGER
	_status_label.text = "PERINGATAN: WAVE %s tiba dalam %d detik!" % [wave_id, eta]


func _on_combat_finished(result: BattleResult) -> void:
	var color := C_OK if result.winner == "defender" else C_DANGER
	_show_toast("PERTEMPURAN: %s MENANG (%d detik)" % [result.winner.to_upper(), result.duration_ticks], color)


func _on_territory_unlocked(sector_id: StringName) -> void:
	_show_toast("WILAYAH TERBUKA: %s" % sector_id.to_upper(), C_ACCENT)
	_status_label.text = "Wilayah terbuka: %s" % sector_id


func _on_quest_progress(_quest_id: StringName, _current: int, _target: int) -> void:
	_refresh_quest()


func _on_quest_completed(quest_id: StringName) -> void:
	_refresh_quest()
	var qt := SystemRefs.quest_tracker()
	if qt != null:
		for q in qt.get_all():
			var d: Dictionary = q
			if d["id"] == quest_id:
				_show_toast("QUEST SELESAI: %s" % d["title"], C_OK)
				_status_label.text = "Quest selesai: %s" % d["title"]
				return
