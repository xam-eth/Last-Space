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

const MODAL_W := 1024   ## 512dp (80% lebar canvas)
const MODAL_H := 504    ## 252dp (70% tinggi canvas)
const TITLE_H := 80     ## 40dp
const CARD_W := 308     ## 154dp — 2 kolom, lebih lega (M3.5)
const CARD_H := 112     ## 56dp
const CARD_ICON := 96   ## 48dp
const DETAIL_W := 340   ## 170dp
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
var _modal: Panel
var _grid: GridContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_class: Label
var _detail_stats: Label
var _detail_cost: Label
var _detail_time: Label
var _detail_status: Label
var _produce_btn: Button
var _close_btn: TextureButton
var _cards: Dictionary = {}   ## def_id -> Button
var _card_labels: Dictionary = {}  ## def_id -> {cost, count}
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

	_modal = Panel.new()
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

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	_modal.add_child(vbox)

	# --- title bar: "FLEET" + close X (40dp touch target) ---
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0, TITLE_H)
	title_row.add_theme_constant_override("separation", 16)
	vbox.add_child(title_row)
	var title := Label.new()
	title.label_settings = _ls(32, C_TEXT)
	title.text = "ARMADA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	_close_btn = TextureButton.new()
	_close_btn.name = "CloseButton"
	_close_btn.custom_minimum_size = Vector2(80, 80)  ## 40dp tombol sekunder
	_close_btn.ignore_texture_size = true
	_close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_close_btn.texture_normal = _load_icon("close")
	_close_btn.pressed.connect(close)
	title_row.add_child(_close_btn)

	# --- body: grid of cards (kiri) + detail panel (kanan) ---
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)

	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = 2  ## M3.5: 2 kolom, card lebih besar & teks jelas
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	body.add_child(_grid)

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
	dv.add_theme_constant_override("separation", 8)
	detail.add_child(dv)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(96, 96)  ## 48dp
	_detail_icon.ignore_texture_size = true
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dv.add_child(_detail_icon)
	_detail_name = Label.new()
	_detail_name.label_settings = _ls(28, C_TEXT)
	dv.add_child(_detail_name)
	_detail_class = Label.new()
	_detail_class.label_settings = _ls(18, C_MUTED)
	dv.add_child(_detail_class)
	_detail_stats = Label.new()
	_detail_stats.label_settings = _ls(18, C_TEXT)
	dv.add_child(_detail_stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(spacer)
	_detail_cost = Label.new()
	_detail_cost.label_settings = _ls(22, C_WARN)
	dv.add_child(_detail_cost)
	_detail_time = Label.new()
	_detail_time.label_settings = _ls(18, C_MUTED)
	dv.add_child(_detail_time)
	_produce_btn = Button.new()
	_produce_btn.name = "ProduceButton"
	_produce_btn.custom_minimum_size = Vector2(0, BTN_BIG_H)  ## 48dp tombol besar
	_produce_btn.text = "PRODUKSI"
	_produce_btn.add_theme_font_size_override("font_size", 28)
	_produce_btn.pressed.connect(_on_produce_pressed)
	dv.add_child(_produce_btn)
	_detail_status = Label.new()
	_detail_status.label_settings = _ls(18, C_ACCENT)
	dv.add_child(_detail_status)

	_build_cards()
	_refresh()


func _build_cards() -> void:
	## Kartu = kapal pemain yang bisa diproduksi (cost non-empty dari data;
	## kapal alien tidak diproduksi pemain).
	for id in GameData.ships.keys():
		var def := GameData.get_ship_def(id)
		if def == null or def.cost.is_empty():
			continue
		_def_order.append(id)
		var card := Button.new()
		card.name = "Card_" + String(id)
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.toggle_mode = true
		var cstyle := _card_style(C_BORDER, C_CARD)
		card.add_theme_stylebox_override("normal", cstyle)
		card.add_theme_stylebox_override("hover", _card_style(C_BORDER_SEL, C_CARD))
		card.add_theme_stylebox_override("pressed", _card_style(C_BORDER_SEL, C_PANEL))
		card.add_theme_stylebox_override("focus", cstyle)
		card.add_theme_font_size_override("font_size", 24)
		card.add_theme_color_override("font_color", C_TEXT)
		## M3.5: card landscape — ikon kiri, nama/kelas/jumlah kanan (teks besar)
		var ch := HBoxContainer.new()
		ch.set_anchors_preset(Control.PRESET_FULL_RECT)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_theme_constant_override("separation", 12)
		card.add_child(ch)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(CARD_ICON, CARD_ICON)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _load_icon(_icon_for(id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_child(icon)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_theme_constant_override("separation", 4)
		ch.add_child(tv)
		var nm := Label.new()
		nm.label_settings = _ls(24, C_TEXT)
		nm.text = def.display_name
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(nm)
		var cls := Label.new()
		cls.label_settings = _ls(20, C_MUTED)
		cls.text = _class_text(def.ship_class) + " — " + _role_text(def.role)
		cls.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(cls)
		var count := Label.new()
		count.label_settings = _ls(18, C_MUTED)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(count)
		_cards[id] = card
		_card_labels[id] = {"count": count}
		card.pressed.connect(_on_card_pressed.bind(id))
		_grid.add_child(card)


func _card_style(border: Color, bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.set_border_width_all(2)
	s.border_color = border
	s.set_content_margin_all(8)
	return s


# ------------------------------------------------------------ public API ----
func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  ## modal blok klik ke arena
	_refresh()
	if _selected == &"" and _def_order.size() > 0:
		select(_def_order[0])
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
		(_cards[id] as Button).button_pressed = (id == def_id)
	_detail_icon.texture = _load_icon(_icon_for(def_id))
	_detail_name.text = def.display_name
	_detail_class.text = "%s — %s" % [_class_text(def.ship_class), _role_text(def.role)]
	_detail_stats.text = _stats_text(def)
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
		_detail_status.text = "Butuh Hangar Pesawat"
		_detail_status.label_settings.font_color = C_DIM
		return false
	if not Economy.can_afford(def.cost):
		_detail_status.text = "Sumber daya tidak cukup"
		_detail_status.label_settings.font_color = C_DIM
		return false
	if ps.enqueue_ship(_selected):
		_detail_status.text = "Produksi dimulai: %s" % def.display_name
		_detail_status.label_settings.font_color = C_ACCENT
		QaMarkers.marker("UI", "PRODUCE", {"id": _selected})
		_refresh()
		return true
	_detail_status.text = "Antrian produksi gagal"
	_detail_status.label_settings.font_color = C_DIM
	return false


func _on_produce_pressed() -> void:
	press_produce()


func _on_card_pressed(def_id: StringName) -> void:
	select(def_id)
	QaMarkers.marker("UI", "SELECT", {"kind": "ship_card", "id": def_id})


# ------------------------------------------------------------- refresh ----
func _refresh() -> void:
	var fs := SystemRefs.fleet_system()
	var bs := SystemRefs.building_system()
	for id in _cards.keys():
		var def := GameData.get_ship_def(id)
		if def == null:
			continue
		var labels: Dictionary = _card_labels[id]
		var total := fs.count_of(id) if fs != null else 0
		var alive := fs.alive_count_of(id) if fs != null else 0
		labels["count"].text = "x%d (%d alive)" % [total, alive]
		if _selected == id:
			_detail_cost.text = "Biaya: " + _cost_text(def.cost)
			var affordable := Economy.can_afford(def.cost)
			_detail_cost.label_settings.font_color = C_WARN if affordable else C_DIM
			_detail_time.text = "Waktu produksi: %ds" % int(round(def.build_time_ticks / float(TimeSystem.TICKS_PER_SECOND)))
			var hangar_ok := bs != null and bs.count_of(&"fighter_hangar") > 0
			var can := affordable and hangar_ok
			_produce_btn.disabled = not can
			_produce_btn.modulate = Color(1, 1, 1, 1) if can else C_DIM
			_produce_btn.tooltip_text = "PRODUKSI (butuh Hangar)" if not hangar_ok else "PRODUKSI"


# ------------------------------------------------------------- helpers ----
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
