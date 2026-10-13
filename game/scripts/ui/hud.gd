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
const MARGIN := 32          ## 16dp — mobile edge margin standar Material
const GAP := 16             ## 8dp — jarak antar zona (Material: min 8dp)
const TOP_BAR_H := 112      ## 56dp — standar Material app bar
const CHIP_W := 236         ## 118dp resource chip
const CHIP_H := 112         ## 56dp — setinggi top bar (satu baris rapi)
const BTN := 96             ## 48dp — touch target minimum Material
const ACTIONS_COLS := 3     ## aksi: bangun | armada | menu (semua berlabel)
const ACTION_CARD_W := 112  ## 56dp — card aksi berlabel (ikon + teks)
const ACTION_CARD_H := 152  ## 76dp — ikon 48dp + label 11dp + padding
const GRID_W := ACTIONS_COLS * ACTION_CARD_W + (ACTIONS_COLS - 1) * GAP  ## 368
const INFO_W := 400         ## 200dp panel info (status)
const QUEST_W := 440        ## 220dp panel objektif
const SEL_MIN_W := 408      ## 204dp minimum panel seleksi (teks + card upgrade)
const BAND_H := 208         ## 104dp — band bawah: info | seleksi | aksi
const TOAST_H := 64         ## 32dp
const ICONS_JSON := "res://assets/ui/icons.json"  ## ikon embedded base64 (wasm tanpa loader .png)
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
const C_CARD := Color(0.055, 0.082, 0.16, 0.9)      ## isian card
const C_BORDER_SEL := Color(0.208, 0.816, 1.0, 1.0)  ## border card aktif/hover

var _top_bar: Control
var _grid: GridContainer
var _info_panel: PanelContainer
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
var _sel_panel: PanelContainer              ## selection panel (BottomBand tengah)
var _upg_label: Label             ## label card upgrade ("TINGKATKAN")
var _upg_cost: Label              ## biaya upgrade di card (label teks)
var _quest_panel: PanelContainer  ## panel objektif (kolom kiri; min-size = konten)
var _bottom_band: HBoxContainer   ## band bawah (info | seleksi | aksi)
var _sel_name: Label
var _sel_level: Label
var _sel_hp: ProgressBar
var _sel_upgrade_btn: Button
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
	_apply_design_frame()  ## full-rect + scale = dpr/2 (ukuran tetap dalam dp)
	_build_top_bar()       ## container HBox (chips | status | menu)
	_build_quest_panel()   ## kolom kiri (LeftColumn; tinggi = konten)
	_build_bottom_band()   ## band bawah: [info | seleksi | aksi] — HBox
	_build_info_panel()
	_build_selection_panel()  ## dalam band (EXPAND) — klik bangunan → upgrade
	_build_action_grid()
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
	get_viewport().size_changed.connect(_on_viewport_resized)  ## resize/rotasi
	_refresh()
	_refresh_quest()
	QaMarkers.marker("HUD", "READY", {"layout": "mobile_landscape_android_adaptive"})
	await get_tree().process_frame  ## tunggu layout container selesai
	await get_tree().process_frame
	_dump_layout()


func _on_viewport_resized() -> void:
	_apply_design_frame()
	_dump_layout.call_deferred()  ## rect & cek anti-tumpuk dihitung ulang (data nyata)


func _apply_design_frame() -> void:
	## HUD FULL-RECT — isi penuh window di SEMUA aspek layar (16:9, 19.5:9,
	## 20:9): root = full window; scale = dpr/2 (lihat _device_pixel_ratio) →
	## ukuran komponen TETAP dalam dp (ikon 48dp, margin 16dp) di semua device.
	## Zona di-anchor ke edge window lewat container: TopBar (top-wide),
	## LeftColumn (kiri, antara top bar & band), BottomBand (bottom-wide:
	## info | seleksi | aksi) → tidak ada black bars, tidak ada tumpang-tindih.
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
	## Dump rect aktual + VERIFIKASI OTOMATIS (data nyata untuk QA):
	##   QA:HUD:LAYOUT  — rect semua zona (device px)
	##   QA:HUD:OVERLAP — jumlah & detail pasangan zona yang bertumpuk (target 0)
	##   QA:HUD:FIT     — panel vs ukuran minimum konten (target semua ok=true)
	var vp := get_viewport().get_visible_rect().size
	var parts: Array[String] = []
	parts.append("viewport[%.0fx%.0f]" % [vp.x, vp.y])
	parts.append("dpr[%.2f]" % _device_pixel_ratio())
	if OS.has_feature("web"):
		parts.append("jsDpr[%s]" % str(JavaScriptBridge.eval("window.LS_DPR", true)))
	parts.append("scale[%.3f]" % scale.x)
	var zones: Array = []
	var stack: Array = [self]
	var wanted := ["TopBar", "QuestPanel", "InfoPanel", "SelectionPanel", "ActionGrid", "Toast"]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			if c is Control and String(c.name) in wanted:
				var ctl := c as Control
				var r := ctl.get_global_rect()
				zones.append(ctl)
				parts.append("%s[%.0f,%.0f %.0fx%.0f]%s" % [ctl.name, r.position.x, r.position.y,
					r.size.x, r.size.y, "" if ctl.visible else "_hidden"])
			stack.append(c)
	if _grid != null and _grid.get_child_count() > 0:
		var cell := _grid.get_child(0) as Control
		var cr := cell.get_global_rect()
		parts.append("cell0[%.0f,%.0f %.0fx%.0f]" % [cr.position.x, cr.position.y, cr.size.x, cr.size.y])
	print("QA:HUD:LAYOUT zones=" + " ".join(parts))

	# --- anti-tumpuk: pairwise intersection zona yang terlihat ---
	var overlaps: Array[String] = []
	for i in range(zones.size()):
		for j in range(i + 1, zones.size()):
			var a := zones[i] as Control
			var b := zones[j] as Control
			if not a.visible or not b.visible:
				continue
			var inter := a.get_global_rect().intersection(b.get_global_rect())
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				overlaps.append("%s-%s:%.0fx%.0f" % [a.name, b.name, inter.size.x, inter.size.y])
	print("QA:HUD:OVERLAP count=%d %s" % [overlaps.size(), " ".join(overlaps)])

	# --- fit: ukuran minimum konten vs panel (tidak boleh melimpah) ---
	var fits: Array[String] = []
	for pair in [[_quest_panel, "QuestPanel"], [_info_panel, "InfoPanel"], [_sel_panel, "SelectionPanel"]]:
		var pnl := pair[0] as Control
		if pnl == null or pnl.get_child_count() == 0:
			continue
		var content := pnl.get_child(0) as Control
		var need := content.get_combined_minimum_size()
		var ok := need.x <= pnl.size.x + 0.5 and need.y <= pnl.size.y + 0.5
		fits.append("%s:%s(%.0fx%.0f<=%.0fx%.0f)" % [pair[1], "ok" if ok else "MELIMPAH", need.x, need.y, pnl.size.x, pnl.size.y])
	print("QA:HUD:FIT " + " ".join(fits))

	# --- label: SEMUA kontrol interaktif wajib punya label teks (kriteria user)
	var au := audit_labels()
	print("QA:HUD:LABELS total=%d labeled=%d unlabeled=%s" % [
		int(au["total"]), int(au["labeled"]), str(au["unlabeled"])])


func audit_labels() -> Dictionary:
	## Audit "semua card punya label teks" (feedback user 2026-10-12): hitung
	## semua kontrol interaktif (Button/TextureButton) di seluruh HUD termasuk
	## modal, dan pastikan tiap satu punya label teks (Button.text atau Label
	## keturunan). Dipakai ui_showcase (gate) + marker QA:HUD:LABELS.
	var total := 0
	var labeled := 0
	var unlabeled: Array[String] = []
	var stack: Array = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
			if c is TextureButton or c is Button:
				total += 1
				if _has_visible_label(c as Control):
					labeled += 1
				else:
					unlabeled.append(String(c.name))
	return {"total": total, "labeled": labeled, "unlabeled": unlabeled}


func _has_visible_label(ctrl: Control) -> bool:
	if ctrl is Button and (ctrl as Button).text.strip_edges() != "":
		return true
	for label in ctrl.find_children("*", "Label", true, false):
		if (label as Label).text.strip_edges() != "":
			return true
	return false


func _build_left_column() -> void:
	## Kolom kiri (antara top bar & band bawah): tempat panel objektif.
	## Region tinggi tetap, tinggi panel = konten (SIZE_SHRINK_BEGIN) → panel
	## tidak pernah melimpah keluar dirinya sendiri.
	var col := VBoxContainer.new()
	col.name = "LeftColumn"
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.anchor_left = 0.0
	col.anchor_right = 0.0
	col.offset_left = MARGIN
	col.offset_right = MARGIN + QUEST_W
	col.offset_top = MARGIN + TOP_BAR_H + GAP
	col.offset_bottom = -(MARGIN + BAND_H + GAP)
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(_quest_panel)


func _build_bottom_band() -> void:
	## Band bawah = HBoxContainer: [InfoPanel | SelectionPanel | ActionGrid].
	## Tumpang-tindih antar panel MUSTAHIL secara struktur (container), dan
	## tetap diverifikasi lewat QA:HUD:OVERLAP (lihat _dump_layout).
	var band := HBoxContainer.new()
	band.name = "BottomBand"
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.offset_left = MARGIN
	band.offset_right = -(MARGIN + GRID_W + GAP)  ## sisakan lajur grid aksi kanan
	band.offset_top = -(MARGIN + BAND_H)
	band.offset_bottom = -MARGIN
	band.add_theme_constant_override("separation", GAP)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_bottom_band = band


func _build_top_bar() -> void:
	## Top bar = HBoxContainer (BUKAN panel kosong besar): chips kiri,
	## status/wave tengah, tombol menu kanan. Tinggi 112 = 56dp (standar
	## Material app bar). Zona ini ikut diverifikasi anti-tumpuk (QA:HUD:OVERLAP).
	var box := HBoxContainer.new()
	box.name = "TopBar"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_left = MARGIN
	box.offset_right = -MARGIN
	box.offset_top = MARGIN
	box.offset_bottom = MARGIN + TOP_BAR_H
	box.add_theme_constant_override("separation", GAP)
	add_child(box)

	# kiri: resource chips (ikon + label + nilai + bar kapasitas)
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", GAP)
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

	# tengah: status arena / indikator wave (dipisah dari tepi oleh container)
	_wave_label = Label.new()
	_wave_label.name = "StatusLabel"
	_wave_label.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.clip_text = true  ## tidak pernah melimpah ke tombol menu
	_wave_label.text = "ARENA BERSIH"
	box.add_child(_wave_label)

	## Catatan: tombol menu (☰) DIPINDAH ke action grid kanan-bawah sebagai card
	## berlabel "MENU" (pola game strategi: aksi utama di thumb zone bawah, dan
	## SEMUA card punya label teks — feedback user 2026-10-12: jangan ikon-saja).


func _make_chip(icon_id: String, label_text: String, accent: Color) -> Dictionary:
	## Resource chip: [ikon 20dp | label 11dp + nilai 16dp] + bar kapasitas.
	## Tinggi 112 = 56dp; konten dihitung agar TIDAK melimpah:
	## margin 12 + baris 74 + gap 6 + bar 8 + margin 12 = 112 ✓
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(CHIP_W, CHIP_H)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(12)
	chip.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(vbox)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.ignore_texture_size = true
	icon.texture = _load_icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var cap := Label.new()
	cap.label_settings = _ls(22, C_MUTED)  ## 11dp labelSmall (minimum Material)
	cap.text = label_text
	cap.clip_text = true
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(cap)
	var value := Label.new()
	value.label_settings = _ls(32, C_TEXT)  ## 16dp bodyLarge
	value.clip_text = true
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(value)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 100.0
	bar.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg_style.set_corner_radius_all(4)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = accent
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("bg", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bar)
	return {"chip": chip, "value": value, "bar": bar}


func _build_action_grid() -> void:
	## Aksi utama (thumb zone kanan-bawah) sebagai CARD BERLABEL:
	## ikon 48dp + nama aksi 11dp. Pola referensi (§7c [25]–[28]): game
	## strategi mobile menaruh aksi utama di bar bawah dengan nama terlihat
	## (Battle bottom-left / Build bottom-right pada Clash of Clans; command
	## bar Age of Empires) — bukan ikon tanpa teks.
	var grid := GridContainer.new()
	grid.name = "ActionGrid"
	_grid = grid
	var actions: Array = [
		{"id": &"build", "icon": "build", "label": "BANGUN", "tip": "Bangun — buka menu konstruksi", "call": Callable(self, "open_build_menu")},
		{"id": &"fleet", "icon": "fleet", "label": "ARMADA", "tip": "Armada — buka menu produksi kapal", "call": Callable(self, "open_ship_menu")},
		{"id": &"menu", "icon": "menu", "label": "MENU", "tip": "Menu — jeda, pengaturan, keluar", "call": Callable(self, "_on_menu_pressed")},
	]
	grid.columns = actions.size()
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Thumb zone kanan-bawah = POSISI TETAP (tidak bergeser saat panel seleksi
	## muncul/hilang — target sentuh tidak boleh berpindah posisi).
	grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grid.offset_left = -(GRID_W + MARGIN)
	grid.offset_right = -MARGIN
	grid.offset_top = -(ACTION_CARD_H + MARGIN)
	grid.offset_bottom = -MARGIN
	add_child(grid)
	for a in actions:
		var card := _make_action_card(a)
		grid.add_child(card)
		_action_buttons[a["id"]] = {"btn": card}


func _make_action_card(a: Dictionary) -> Button:
	## Card aksi: Button (seluruh card = touch target ≥48dp) + isi VBox
	## [ikon | label] yang tidak memblok input (MOUSE_FILTER_IGNORE).
	var card := Button.new()
	card.name = "Action_" + String(a["id"])
	card.custom_minimum_size = Vector2(ACTION_CARD_W, ACTION_CARD_H)
	card.tooltip_text = String(a["tip"])
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _card_style(C_BORDER, C_PANEL))
	card.add_theme_stylebox_override("hover", _card_style(C_BORDER_SEL, C_CARD))
	card.add_theme_stylebox_override("pressed", _card_style(C_BORDER_SEL, C_PANEL))
	card.add_theme_stylebox_override("disabled", _card_style(C_BORDER, C_PANEL))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(BTN, BTN)  ## 48dp ikon
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.ignore_texture_size = true
	icon.texture = _load_icon(String(a["icon"]))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var lbl := Label.new()
	lbl.label_settings = _ls(22, C_TEXT)  ## 11dp labelSmall (minimum Material)
	lbl.text = String(a["label"])
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	card.pressed.connect(a["call"])
	return card


func _card_style(border: Color, bg: Color) -> StyleBoxFlat:
	## Style card bersama (aksi & tombol berlabel) — radius 16, border 2, isi 12.
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(16)
	st.set_border_width_all(2)
	st.border_color = border
	st.set_content_margin_all(12)
	return st


func _build_info_panel() -> void:
	## Panel status/INFO (kiri dalam BottomBand): status + hasil aktif.
	## Lebar tetap 220dp; tinggi mengikuti band (stretch) — teks di atas,
	## tidak ada elemen yang bisa saling menimpa (VBox).
	var panel := PanelContainer.new()
	panel.name = "InfoPanel"
	_info_panel = panel
	panel.custom_minimum_size = Vector2(INFO_W, 0)
	panel.size_flags_vertical = Control.SIZE_FILL  ## ikut tinggi band (konten di atas)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_band.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	_status_label = Label.new()
	_status_label.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Pusat komando aktif."
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_status_label)
	var result := Label.new()
	result.name = "ResultLabel"
	result.label_settings = _ls(28, C_ACCENT)  ## 14dp bodyMedium
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(result)


func _build_toast() -> void:
	## Toast top-center (di bawah top bar): hasil battle / territory.
	## Lebar responsif (min 560, maks 60% lebar canvas) supaya tidak pernah
	## menimpa chips atau tombol menu.
	## Toast dibatasi ke jalur arena: mulai setelah kolom kiri, berakhir sebelum
	## grid aksi → tidak pernah menimpa panel objektif / tombol aksi (QA:HUD:OVERLAP).
	_toast_panel = Panel.new()
	_toast_panel.name = "Toast"
	_toast_panel.anchor_left = 0.0
	_toast_panel.anchor_right = 1.0
	_toast_panel.offset_left = MARGIN + QUEST_W + GAP
	_toast_panel.offset_right = -(MARGIN + GRID_W + GAP)
	_toast_panel.offset_top = MARGIN + TOP_BAR_H + GAP
	_toast_panel.offset_bottom = MARGIN + TOP_BAR_H + GAP + TOAST_H
	_toast_panel.custom_minimum_size = Vector2(0, TOAST_H)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.063, 0.125, 0.92)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = C_ACCENT
	style.set_content_margin_all(12)
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_panel.add_child(_toast_label)


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
	## Panel kiri (kolom kiri, di antara top bar dan bottom band). Tinggi =
	## KONTEN (SIZE_SHRINK_BEGIN) → secara struktur tidak mungkin melimpah
	## keluar panel (temuan M3.6: baris ke-4 tumpah ke panel info).
	var panel := PanelContainer.new()
	panel.name = "QuestPanel"
	_quest_panel = panel
	panel.custom_minimum_size = Vector2(QUEST_W, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_left_column()  ## LeftColumn.add_child(panel) — zonasi terstruktur
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)
	var qicon := TextureRect.new()
	qicon.custom_minimum_size = Vector2(32, 32)
	qicon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_quest_rows.add_theme_constant_override("separation", 8)
	_quest_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_quest_rows)


func _refresh_quest() -> void:
	## Baris objektif SATU BARIS (mark vektor | nama | bar | hitungan):
	## tidak ada label yang bisa saling menimpa, dan tinggi baris tetap.
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
		## Mark vektor (bukan glyph font — "[ ]" tidak dirender baik):
		## belum = kotak kosong outline; selesai = kotak terisi hijau + inti putih.
		var mark := Panel.new()
		mark.custom_minimum_size = Vector2(24, 24)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mstyle := StyleBoxFlat.new()
		mstyle.set_corner_radius_all(6)
		mstyle.set_border_width_all(2)
		if d["done"]:
			mstyle.bg_color = C_OK
			mstyle.border_color = C_OK
		else:
			mstyle.bg_color = Color(0, 0, 0, 0.25)
			mstyle.border_color = C_MUTED
		mark.add_theme_stylebox_override("panel", mstyle)
		if d["done"]:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(10, 10)
			dot.set_anchors_preset(Control.PRESET_CENTER)
			dot.offset_left = -5
			dot.offset_right = 5
			dot.offset_top = -5
			dot.offset_bottom = 5
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var dstyle := StyleBoxFlat.new()
			dstyle.bg_color = C_TEXT
			dstyle.set_corner_radius_all(3)
			dot.add_theme_stylebox_override("panel", dstyle)
			mark.add_child(dot)
		row.add_child(mark)
		var nm := Label.new()
		nm.label_settings = _ls(24, C_OK if d["done"] else C_TEXT)  ## 12dp
		nm.text = String(d["title"])
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nm)
		var prog := ProgressBar.new()
		prog.custom_minimum_size = Vector2(72, 8)
		prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prog.max_value = float(maxi(int(d["target"]), 1))
		prog.value = float(int(d["current"]))
		prog.show_percentage = false
		var pbg := StyleBoxFlat.new()
		pbg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
		pbg.set_corner_radius_all(4)
		var pfill := StyleBoxFlat.new()
		pfill.bg_color = C_OK if d["done"] else C_ACCENT
		pfill.set_corner_radius_all(4)
		prog.add_theme_stylebox_override("bg", pbg)
		prog.add_theme_stylebox_override("fill", pfill)
		prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(prog)
		var pct := Label.new()
		pct.label_settings = _ls(22, C_MUTED)  ## 11dp labelSmall
		pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pct.custom_minimum_size = Vector2(56, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.text = "%d/%d" % [int(d["current"]), int(d["target"])]
		pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pct)


func _build_selection_panel() -> void:
	## Panel seleksi (tengah dalam BottomBand): [nama+level+HP | CARD UPGRADE
	## berlabel "TINGKATKAN" + biaya]. Semua aksi punya label teks (feedback
	## user 2026-10-12) dan tiap elemen punya barisnya sendiri (tidak menimpa).
	var panel := PanelContainer.new()
	panel.name = "SelectionPanel"
	_sel_panel = panel
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.custom_minimum_size = Vector2(SEL_MIN_W, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	_bottom_band.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	# --- kiri: nama / level / HP ---
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 6)
	row.add_child(texts)
	_sel_name = Label.new()
	_sel_name.label_settings = _ls(28, C_TEXT)  ## 14dp bodyMedium
	_sel_name.clip_text = true
	texts.add_child(_sel_name)
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	texts.add_child(sub_row)
	_sel_level = Label.new()
	_sel_level.label_settings = _ls(22, C_MUTED)  ## 11dp labelSmall
	_sel_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_row.add_child(_sel_level)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	texts.add_child(hp_row)
	var hp_cap := Label.new()
	hp_cap.label_settings = _ls(22, C_MUTED)  ## 11dp
	hp_cap.text = "HP"
	hp_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(hp_cap)
	_sel_hp = ProgressBar.new()
	_sel_hp.custom_minimum_size = Vector2(0, 12)
	_sel_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sel_hp.max_value = 100.0
	_sel_hp.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg_style.set_corner_radius_all(4)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = C_OK
	fill_style.set_corner_radius_all(4)
	_sel_hp.add_theme_stylebox_override("bg", bg_style)
	_sel_hp.add_theme_stylebox_override("fill", fill_style)
	hp_row.add_child(_sel_hp)
	# --- kanan: card upgrade berlabel + biaya ---
	_sel_upgrade_btn = Button.new()
	_sel_upgrade_btn.name = "UpgradeButton"
	_sel_upgrade_btn.custom_minimum_size = Vector2(140, ACTION_CARD_H)
	_sel_upgrade_btn.focus_mode = Control.FOCUS_NONE
	_sel_upgrade_btn.add_theme_stylebox_override("normal", _card_style(C_ACCENT, C_CARD))
	_sel_upgrade_btn.add_theme_stylebox_override("hover", _card_style(C_BORDER_SEL, C_PANEL))
	_sel_upgrade_btn.add_theme_stylebox_override("pressed", _card_style(C_BORDER_SEL, C_CARD))
	_sel_upgrade_btn.add_theme_stylebox_override("disabled", _card_style(C_BORDER, C_PANEL))
	_sel_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	row.add_child(_sel_upgrade_btn)
	var ub := VBoxContainer.new()
	ub.set_anchors_preset(Control.PRESET_FULL_RECT)
	ub.add_theme_constant_override("separation", 4)
	ub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_upgrade_btn.add_child(ub)
	var uicon := TextureRect.new()
	uicon.custom_minimum_size = Vector2(56, 56)
	uicon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	uicon.ignore_texture_size = true
	uicon.texture = _load_icon("upgrade")
	uicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	uicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ub.add_child(uicon)
	_upg_label = Label.new()
	_upg_label.label_settings = _ls(22, C_TEXT)  ## 11dp labelSmall
	_upg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upg_label.text = "TINGKATKAN"
	_upg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ub.add_child(_upg_label)
	_upg_cost = Label.new()
	_upg_cost.label_settings = _ls(22, C_WARN)  ## 11dp — biaya
	_upg_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upg_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ub.add_child(_upg_cost)


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
	_dump_layout.call_deferred()  ## rect terbaru (panel seleksi terlihat) untuk QA


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
	_sel_level.text = "Lv %d · %s" % [b.level, b.def.id]
	var max_hp := b.get_max_hp()
	_sel_hp.value = (100.0 * b.hp / max_hp) if max_hp > 0 else 0.0
	if b.level >= b.def.max_level:
		_sel_upgrade_cost = {}
		_upg_label.text = "LEVEL MAKS"
		_upg_label.label_settings.font_color = C_DIM
		_upg_cost.text = "—"
		_upg_cost.label_settings.font_color = C_DIM
		_sel_upgrade_btn.disabled = true
		_sel_upgrade_btn.tooltip_text = "Level maksimum"
	else:
		_sel_upgrade_cost = b.def.get_cost_for_level(b.level + 1)
		var affordable := Economy.can_afford(_sel_upgrade_cost)
		_upg_label.text = "TINGKATKAN Lv%d" % (b.level + 1)
		_upg_label.label_settings.font_color = C_TEXT if affordable else C_DIM
		_upg_cost.text = _cost_text(_sel_upgrade_cost)
		_upg_cost.label_settings.font_color = C_WARN if affordable else C_DIM
		_sel_upgrade_btn.disabled = not affordable
		_sel_upgrade_btn.tooltip_text = "Tingkatkan ke Lv%d — %s" % [b.level + 1, _cost_text(_sel_upgrade_cost)]


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
