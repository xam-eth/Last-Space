extends Control
## ShipMenu — modal menu produksi armada (GAMEPLAY_FLOW.md §3 Frame 6, M3 #2).
## Pola Doomsday (Hero menu, docs/references/doomsday/FRAME_BY_FRAME.md F7):
## title + close X + grid of cards + detail panel kanan + tombol besar bawah.
##
## Ukuran sama dengan Build menu (UI_UX_DESIGN.md §3.3): modal 1024×504
## (512×252dp = 80%×70% canvas), anchor center semua aspek; card 188×188 (94dp);
## tombol PRODUCE besar tinggi 48dp.
##
## Aturan: UI read-only — memanggil API sistem yang sama dengan gameplay
## (ProductionSystem.enqueue_ship — atomic, cek hangar + dana). Hanya kapal
## pemain yang tampil (cost non-empty dari data; kapal alien tidak diproduksi).

## Layout sama dengan build menu (M3.6): lebar/tinggi dari hasil hitung teks
## aktual — card 177dp, detail 190dp, modal 576×280dp.
const MODAL_W := 1088   ## 544dp (< max-width dialog Material 560dp)
const MODAL_H := 560    ## 280dp (anggaran: title 96 + tab 96 + 2×8 + grid 320)
const TITLE_H := 80     ## 40dp
const GRID_COLS := 4    ## M3.7c: 4 kolom tile 152 (pola grid katalog CoC)
const DETAIL_W := 360   ## 180dp — body 11dp muat tanpa terpotong (M3.6)
const BTN_BIG_H := 96   ## 48dp tombol besar
const ICONS_JSON := "res://assets/ui/icons.json"

const C_PANEL := Color(0.043, 0.063, 0.125, 0.92)
const C_CARD := Color(0.055, 0.082, 0.16, 0.9)
const C_BORDER := Color(0.208, 0.816, 1.0, 0.55)
const C_BORDER_SEL := Color(0.208, 0.816, 1.0, 1.0)
const C_TEXT := Color(0.918, 0.965, 1.0, 1.0)
const C_MUTED := Color(0.62, 0.70, 0.80, 1.0)
const C_ACCENT := Color(0.208, 0.816, 1.0, 1.0)
const C_WARN := Color(1.0, 0.72, 0.30, 1.0)
const C_DIM := Color(0.45, 0.45, 0.50, 0.85)

var _dim: ColorRect
var _modal: PanelContainer
var _grid: GridContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_class: Label
var _detail_stats: Label
var _detail_cost: Label
var _detail_time: Label
var _detail_status: Label
var _res_strip: Label  ## strip resource di baris judul (M3.6)
var _vbox: VBoxContainer   ## host konten modal (diisi _ready)
var _tab_row: HBoxContainer
var _tab_group := ButtonGroup.new()
var _tabs: Dictionary = {}   ## kelas kapal -> Button (tab IKON, tanpa label kata)
var _active_cat: StringName = &"all"
var _produce_btn: Button
var _close_btn: Button
var _cards: Dictionary = {}     ## def_id -> Button (tile katalog, tanpa teks)
var _card_cat: Dictionary = {}  ## def_id -> StringName kelas kapal
var _selected: StringName = &""
var _icon_cache: Dictionary = {}
var _def_order: Array[StringName] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  ## saat hidden tidak blok arena
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  ## klik luar modal = tutup
	_dim.gui_input.connect(func(_e): close())
	add_child(_dim)

	## PanelContainer (bukan Panel): stylebox margin BENAR-BENAR diterapkan ke
	## anak (temuan: Panel mengabaikan content margin untuk anak anchored →
	## konten menempel ke tepi frame, tidak ada margin dalam 16dp).
	_modal = PanelContainer.new()
	_modal.name = "Modal"
	_modal.custom_minimum_size = Vector2(MODAL_W, MODAL_H)
	## Anchor CENTER — modal selalu di tengah SEMUA aspek layar.
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

	_vbox = VBoxContainer.new()
	_vbox.name = "ModalBody"
	_vbox.add_theme_constant_override("separation", 8)
	_modal.add_child(_vbox)

	# --- title bar: "FLEET" + close X (40dp touch target) ---
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0, TITLE_H)
	title_row.add_theme_constant_override("separation", 16)
	_vbox.add_child(title_row)
	var title := Label.new()
	title.label_settings = _ls(32, C_TEXT)
	title.text = "ARMADA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	## strip resource di modal (chip HUD tertutup dim → konteks tetap terlihat)
	_res_strip = Label.new()
	_res_strip.label_settings = _ls(24, C_TEXT)
	_res_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_res_strip)
	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.custom_minimum_size = Vector2(180, 96)  ## 48dp tinggi (touch target)
	_close_btn.text = "TUTUP"
	_close_btn.icon = _load_icon("close")
	_close_btn.add_theme_constant_override("icon_max_width", 48)  ## ikon 24dp
	_close_btn.add_theme_font_size_override("font_size", 22)  ## 11dp labelSmall
	_close_btn.add_theme_stylebox_override("normal", _close_style(C_BORDER))
	_close_btn.add_theme_stylebox_override("hover", _close_style(C_BORDER_SEL))
	_close_btn.add_theme_stylebox_override("pressed", _close_style(C_ACCENT))
	_close_btn.pressed.connect(close)
	title_row.add_child(_close_btn)

	# --- baris tab kelas kapal: IKON saja (48dp persegi, tanpa label kata) ---
	_build_tabs()

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	_vbox.add_child(body)

	## Grid di dalam ScrollContainer (anggaran 320px = 2 baris tile 152).
	var scroll := ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)

	var detail := Panel.new()
	detail.name = "DetailPanel"
	detail.custom_minimum_size = Vector2(DETAIL_W, 0)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dstyle := StyleBoxFlat.new()
	dstyle.bg_color = C_CARD
	dstyle.set_corner_radius_all(16)
	dstyle.set_border_width_all(2)
	dstyle.border_color = C_BORDER
	dstyle.set_content_margin_all(16)
	detail.add_theme_stylebox_override("panel", dstyle)
	body.add_child(detail)
	var dv := VBoxContainer.new()
	dv.set_anchors_preset(Control.PRESET_FULL_RECT)
	## 4dp: total konten detail harus muat di panel (tidak meluber — temuan foto)
	dv.add_theme_constant_override("separation", 4)
	detail.add_child(dv)
	## Header detail: art kecil + nama/kelas (hemat tinggi — anggaran 320px)
	var dhead := HBoxContainer.new()
	dhead.name = "DetailHeader"
	dhead.add_theme_constant_override("separation", 12)
	dv.add_child(dhead)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(48, 48)  ## 24dp
	_detail_icon.ignore_texture_size = true
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dhead.add_child(_detail_icon)
	var hcol := VBoxContainer.new()
	hcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hcol.add_theme_constant_override("separation", 0)
	dhead.add_child(hcol)
	_detail_name = Label.new()
	_detail_name.label_settings = _ls(28, C_TEXT)
	hcol.add_child(_detail_name)
	_detail_class = Label.new()
	_detail_class.label_settings = _ls(22, C_MUTED)  ## 11dp
	hcol.add_child(_detail_class)
	## Blok stats = area BERGESER (temuan foto 05_ship_menu: 6 baris stats +
	## tombol PRODUKSI keluar dari modal). Dengan ScrollContainer, tombol aksi
	## selalu di dalam panel berapa pun panjang stats-nya.
	var stat_scroll := ScrollContainer.new()
	stat_scroll.name = "DetailScroll"
	stat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(stat_scroll)
	_detail_stats = Label.new()
	_detail_stats.label_settings = _ls(24, C_TEXT)  ## 12dp bodyMedium
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_scroll.add_child(_detail_stats)
	_detail_cost = Label.new()
	_detail_cost.label_settings = _ls(22, C_WARN)
	dv.add_child(_detail_cost)
	_detail_time = Label.new()
	_detail_time.label_settings = _ls(22, C_MUTED)  ## 11dp
	dv.add_child(_detail_time)
	_produce_btn = Button.new()
	_produce_btn.name = "ProduceButton"
	_produce_btn.custom_minimum_size = Vector2(0, 88)  ## 44dp — lebih ringkas
	_produce_btn.text = "PRODUKSI"
	_produce_btn.add_theme_font_size_override("font_size", 28)
	_produce_btn.pressed.connect(_on_produce_pressed)
	dv.add_child(_produce_btn)
	_detail_status = Label.new()
	_detail_status.label_settings = _ls(22, C_ACCENT)  ## 11dp
	_detail_status.visible = false  ## hanya tampil saat ada pesan (hemat tinggi)
	dv.add_child(_detail_status)

	_build_cards()
	_refresh()


func _build_tabs() -> void:
	## Tab kelas kapal = IKON saja (menu tidak semua elemennya berlabel).
	_tab_row = HBoxContainer.new()
	_tab_row.name = "CategoryTabs"
	_tab_row.custom_minimum_size = Vector2(0, CatalogTile.TAB)
	_tab_row.add_theme_constant_override("separation", 16)
	_vbox.add_child(_tab_row)
	var cats: Array[StringName] = [&"all"]
	var seen := {}
	for id in GameData.ships.keys():
		var def := GameData.get_ship_def(id)
		if def == null or def.cost.is_empty():
			continue
		var c := StringName(def.ship_class)
		if not seen.has(c):
			seen[c] = true
			cats.append(c)
	for c in cats:
		var tab: Button = CatalogTile.make_tab(_load_icon("grid" if c == &"all" else "interceptor"),
			_icon_tip(c), _tab_group, C_BORDER, C_CARD, C_BORDER_SEL)
		tab.name = "Tab_" + String(c)
		tab.pressed.connect(_on_tab_pressed.bind(c))
		_tab_row.add_child(tab)
		_tabs[c] = tab
	## Satu tab = tidak perlu baris tab (menu tidak semua elemennya berlabel).
	_tab_row.visible = cats.size() > 1
	if _tabs.has(&"all"):
		(_tabs[&"all"] as Button).button_pressed = true


func _on_tab_pressed(cat: StringName) -> void:
	_active_cat = cat
	_apply_tab()


func _apply_tab() -> void:
	for id in _cards.keys():
		(_cards[id] as Control).visible = _active_cat == &"all" or _card_cat[id] == _active_cat
	_audit_cards()


func _build_cards() -> void:
	## Tile katalog: ikon 70% + badge angka, TANPA label teks di tile.
	## Kapal pemain = punya cost (alien/asset showcase tidak masuk katalog).
	var fs := SystemRefs.fleet_system()
	for id in GameData.ships.keys():
		var def := GameData.get_ship_def(id)
		if def == null or def.cost.is_empty():
			continue
		var tile: Button = CatalogTile.make_tile(_load_icon(_icon_for(id)),
			fs.count_of(id) if fs != null else 0,
			def.display_name, _tab_group, C_BORDER, C_CARD, C_BORDER_SEL, C_TEXT)
		tile.name = "Tile_" + String(id)
		tile.pressed.connect(_on_card_pressed.bind(id))
		_cards[id] = tile
		_card_cat[id] = StringName(def.ship_class)
		_grid.add_child(tile)
		_def_order.append(id)
	_apply_tab()


## Angka badge kuantitas pada tile (0 = badge tidak tampil) — untuk QA & test.
func qty_of(def_id: StringName) -> int:
	if not _cards.has(def_id):
		return 0
	return CatalogTile.qty_of(_cards[def_id])


## Audit card katalog (kriteria user: mayoritas card TANPA label teks).
func audit_cards() -> Dictionary:
	return _audit_cards()


func _audit_cards() -> Dictionary:
	var shown: Array = []
	for id in _cards.keys():
		if (_cards[id] as Control).visible:
			shown.append(_cards[id])
	var au: Dictionary = CatalogTile.audit(shown, "ship", String(_active_cat))
	for id in _cards.keys():
		var tile := _cards[id] as Control
		if not tile.visible:
			continue
		var labels := CatalogTile.label_nodes(tile)
		QaMarkers.marker("CARD", "TILE", {"menu": "ship", "id": String(id),
			"text_nodes": labels.size(), "labels": str(labels),
			"qty": CatalogTile.qty_of(tile),
			"icon_ratio": CatalogTile.icon_ratio() * 100.0})
	QaMarkers.marker("CARD", "SUMMARY", {"menu": "ship", "tab": String(_active_cat),
		"tiles": au["tiles"], "with_text": au["with_text"],
		"label_free_pct": int(round(CatalogTile.label_free_ratio(au) * 100.0)),
		"icon_ratio": au["icon_ratio"]})
	return au


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  ## modal blok klik ke arena
	if _selected == &"" and _def_order.size() > 0:
		select(_def_order[0])
	_refresh()
	QaMarkers.marker("UI", "MENU", {"event": "open", "kind": "ship"})


func close() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	QaMarkers.marker("UI", "MENU", {"event": "close", "kind": "ship"})


func is_open() -> bool:
	return visible


func card_count() -> int:
	return _cards.size()


func get_selected() -> StringName:
	return _selected


func select(def_id: StringName) -> void:
	## Pilih kapal di grid → update detail panel (stats dari data .tres).
	var def := GameData.get_ship_def(def_id)
	if def == null:
		return
	_selected = def_id
	for id in _cards.keys():
		if id != def_id:
			(_cards[id] as Button).button_pressed = false
	if _active_cat != &"all" and _card_cat.get(def_id, &"") != _active_cat:
		_on_tab_pressed(StringName(def.ship_class))  ## tile wajib tampil agar terpilih
	if _cards.has(def_id):
		(_cards[def_id] as Button).button_pressed = true
	_detail_icon.texture = _load_icon(_icon_for(def_id))
	_detail_name.text = def.display_name
	_detail_class.text = "KELAS   %s — %s" % [_class_text(def.ship_class), _role_text(def.role)]  ## label field
	_detail_stats.text = "STATS   " + _stats_text(def)  ## label field
	_refresh()


## Tombol PRODUCE besar ditekan — enqueue produksi (atomic via
## ProductionSystem: cek hangar + dana). Mengembalikan true jika berhasil.
func press_produce() -> bool:
	var def := GameData.get_ship_def(_selected)
	var bs := SystemRefs.building_system()
	var ps := SystemRefs.production_system()
	if def == null or bs == null or ps == null:
		return false
	if bs.count_of(&"fighter_hangar") <= 0:
		_detail_status.visible = true
		_detail_status.text = "Butuh Hangar Pesawat"
		_detail_status.label_settings.font_color = C_DIM
		return false
	if not Economy.can_afford(def.cost):
		_detail_status.visible = true
		_detail_status.text = "Sumber daya tidak cukup"
		_detail_status.label_settings.font_color = C_DIM
		return false
	if ps.enqueue_ship(_selected):
		_detail_status.visible = true
		_detail_status.text = "Produksi dimulai: %s" % def.display_name
		_detail_status.label_settings.font_color = C_ACCENT
		QaMarkers.marker("UI", "PRODUCE", {"id": _selected})
		_refresh()
		return true
	_detail_status.visible = true
	_detail_status.text = "Antrian produksi gagal"
	_detail_status.label_settings.font_color = C_DIM
	return false


func _on_produce_pressed() -> void:
	press_produce()


func _on_card_pressed(def_id: StringName) -> void:
	select(def_id)
	QaMarkers.marker("UI", "SELECT", {"kind": "ship_card", "id": def_id})


# ------------------------------------------------------------- refresh ----
func _update_res_strip() -> void:
	if _res_strip == null:
		return
	_res_strip.text = "ENERGI %d/%d   MINERAL %d/%d" % [
		Economy.get_amount(&"energy"), Economy.get_cap(&"energy"),
		Economy.get_amount(&"minerals"), Economy.get_cap(&"minerals"),
	]


func _refresh() -> void:
	## Perbarui badge angka di tile (satu-satunya teks di tile) + panel detail.
	_update_res_strip()
	var fs := SystemRefs.fleet_system()
	var bs := SystemRefs.building_system()
	for id in _cards.keys():
		CatalogTile.set_qty(_cards[id], fs.count_of(id) if fs != null else 0)
	var def := GameData.get_ship_def(_selected)
	if def == null:
		return
	var affordable := Economy.can_afford(def.cost)
	_detail_cost.text = "BIAYA   " + _cost_text(def.cost)
	_detail_cost.label_settings.font_color = C_WARN if affordable else C_DIM
	_detail_time.text = "WAKTU PRODUKSI   %ds" % int(round(def.build_time_ticks / float(TimeSystem.TICKS_PER_SECOND)))
	var hangar_ok := bs != null and bs.count_of(&"fighter_hangar") > 0
	var can := affordable and hangar_ok
	_produce_btn.disabled = not can
	_produce_btn.modulate = Color(1, 1, 1, 1) if can else C_DIM
	_produce_btn.tooltip_text = "PRODUKSI (butuh Hangar)" if not hangar_ok else "PRODUKSI"
	_audit_cards()


# ------------------------------------------------------------- helpers ----
func _icon_tip(cat: StringName) -> String:
	## Tooltip tab (hover desktop) — teks tidak tercetak di tab (ikon saja).
	return "Semua armada" if cat == &"all" else _class_text(String(cat))


func _class_text(cls: String) -> String:
	## M3.5: label kelas kapal — Bahasa Indonesia
	match cls:
		"fighter": return "PESAWAT TEMPUR"
		_: return cls.to_upper()


func _role_text(role: String) -> String:
	## M3.5: label peran kapal — Bahasa Indonesia
	match role:
		"scout": return "PRAMALA"
		"interceptor": return "PENGINTAS"
		_: return role.to_upper()


func _stats_text(def: ShipDef) -> String:
	var lines: Array[String] = []
	lines.append("HP %d" % def.max_hp)
	var atk := 0
	var wname := "-"
	if def.weapon_id != &"":
		var w := GameData.get_weapon_def(def.weapon_id)
		if w != null:
			atk = w.damage * def.weapon_count
			wname = String(def.weapon_id)
	lines.append("ATK %d (%s ×%d)" % [atk, wname, def.weapon_count])
	lines.append("ARMOR %d" % def.armor)
	lines.append("KECEPATAN %.1f u/s" % def.speed)
	lines.append("PASOKAN %d" % def.fleet_supply)
	return "\n".join(lines)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if int(cost.get("energy", 0)) > 0:
		parts.append("E%d" % int(cost.get("energy", 0)))
	if int(cost.get("minerals", 0)) > 0:
		parts.append("M%d" % int(cost.get("minerals", 0)))
	return " ".join(parts) if not parts.is_empty() else "GRATIS"


var _icon_map := {
	&"shp_001_interceptor": "interceptor",
}


func _icon_for(id: StringName) -> String:
	return _icon_map.get(id, "interceptor")


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
