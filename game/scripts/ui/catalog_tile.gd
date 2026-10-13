class_name CatalogTile
extends RefCounted
## CatalogTile — komponen bersama katalog BANGUN & ARMADA (M3.7c).
##
## Tata letak ditiru dari UI game strategi mobile nyata (riset terdokumentasi di
## docs/REFERENCES_CARD_LAYOUT.md — bukan asumsi):
##   - Clash of Clans (tombol Build/Shop): baris TAB IKON di bawah header,
##     lalu grid TILE besar yang didominasi art; nama & biaya TIDAK dicetak di
##     tile, melainkan muncul di panel detail setelah tile dipilih. Badge angka
##     (kuantitas) menempel di sudut tile.
##   - Doomsday: Last Survivors (modal BAG): panel penuh + tombol aksi besar.
##   - Rise of Kingdoms / Evony: detail item = panel terpisah, label field
##     (KATEGORI/BIAYA/WAKTU) hanya ada di sana.
##
## Kriteria user (2026-10-13): "semua card itu 70% tidak ada teks label; yang
## pakai label cuma menu" → tile katalog = IKON saja + badge ANGKA (angka
## kuantitas bukan label kata); label kata hanya di chrome menu (judul, panel
## detail, tombol aksi), dan tidak semua elemen menu berlabel (tab = ikon saja).
##
## Ukuran (design px; 1px = 0,5dp — UI_UX_DESIGN.md §3):
##   TILE 152 = 76dp (touch target minimum Material 48dp — jauh di atas)
##   ikon 70% sisi tile (106px = 53dp) → art dominan, satu-satunya isi tile
##   TAB 96 = 48dp persegi, ikon 60px = 30dp

const TILE := 152.0        ## 76dp
const ICON_RATIO := 0.70   ## kotak ikon = 70% sisi tile
const TAB := 96.0          ## 48dp — touch target minimum Material
const TAB_ICON_RATIO := 0.62
const BADGE_NAME := "QtyBadge"
const BADGE_LABEL := "QtyLabel"
const LOCK_NAME := "LockBadge"
const ICON_NAME := "TileIcon"


static func icon_ratio() -> float:
	return ICON_RATIO


## Tile katalog: ikon besar + badge angka. TIDAK ada label kata di tile.
static func make_tile(icon: Texture2D, qty: int, tip: String, group: ButtonGroup,
		c_border: Color, c_card: Color, c_sel: Color, c_text: Color,
		size: float = TILE) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(size, size)
	tile.toggle_mode = true
	tile.button_group = group
	tile.tooltip_text = tip  ## hover desktop — bukan label tercetak di tile
	tile.add_theme_stylebox_override("normal", _bg(c_card, c_border))
	tile.add_theme_stylebox_override("hover", _bg(c_card, c_sel))
	tile.add_theme_stylebox_override("pressed", _bg(c_card, c_sel))
	tile.add_theme_stylebox_override("focus", _bg(c_card, c_border))
	var on := _bg(c_card.lightened(0.08), c_sel)
	on.set_border_width_all(4)
	tile.add_theme_stylebox_override("checked", on)

	# --- art: ikon 70% sisi tile, terpusat (satu-satunya isi tile) ---
	var ic := TextureRect.new()
	ic.name = ICON_NAME
	ic.texture = icon
	ic.ignore_texture_size = true
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var half := size * ICON_RATIO / 2.0
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -half
	ic.offset_right = half
	ic.offset_top = -half
	ic.offset_bottom = half
	tile.add_child(ic)

	# --- badge angka kuantitas (ANGKA, bukan label kata) ---
	var badge := PanelContainer.new()
	badge.name = BADGE_NAME
	var m := size * 0.04
	var bh := size * 0.22
	var bw := size * 0.36
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -(m + bw)
	badge.offset_right = -m
	badge.offset_top = m
	badge.offset_bottom = m + bh
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.043, 0.075, 0.16, 0.95)
	bstyle.set_corner_radius_all(int(bh / 2.0))
	bstyle.set_border_width_all(2)
	bstyle.border_color = c_sel
	bstyle.set_content_margin_all(2)
	bstyle.content_margin_left = 8
	bstyle.content_margin_right = 8
	badge.add_theme_stylebox_override("panel", bstyle)
	var bl := Label.new()
	bl.name = BADGE_LABEL
	bl.label_settings = _ls(20, c_text)  ## 10dp — angka ringkas
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(bl)
	tile.add_child(badge)
	set_qty(tile, qty)

	# --- overlay gembok (tile belum terbuka) — ikon, tanpa teks ---
	var lock := TextureRect.new()
	lock.name = LOCK_NAME
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock.ignore_texture_size = true
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.visible = false
	tile.add_child(lock)
	return tile


## Badge hanya tampil bila pemain sudah punya ≥1 unit (pola CoC: kurangi noise).
static func set_qty(tile: Control, qty: int) -> void:
	var badge := tile.get_node_or_null(BADGE_NAME) as Control
	if badge == null:
		return
	badge.visible = qty >= 1
	var bl := tile.get_node_or_null(BADGE_NAME + "/" + BADGE_LABEL) as Label
	if bl != null:
		bl.text = "x%d" % qty


## Nilai angka pada badge tile (0 bila badge tidak tampil) — dipakai QA.
static func qty_of(tile: Control) -> int:
	var badge := tile.get_node_or_null(BADGE_NAME) as Control
	if badge == null or not badge.visible:
		return 0
	var bl := tile.get_node_or_null(BADGE_NAME + "/" + BADGE_LABEL) as Label
	if bl == null:
		return 0
	return int(bl.text.trim_prefix("x")) if bl.text.begins_with("x") else 0


static func set_locked(tile: Control, locked: bool, lock_icon: Texture2D) -> void:
	var lock := tile.get_node_or_null(LOCK_NAME) as TextureRect
	if lock == null:
		return
	lock.texture = lock_icon
	lock.visible = locked
	tile.disabled = locked


## Tab kategori: IKON saja (menu tidak semua elemennya berlabel).
static func make_tab(icon: Texture2D, tip: String, group: ButtonGroup,
		c_border: Color, c_card: Color, c_sel: Color, size: float = TAB) -> Button:
	var tab := Button.new()
	tab.custom_minimum_size = Vector2(size, size)
	tab.toggle_mode = true
	tab.button_group = group
	tab.tooltip_text = tip
	tab.add_theme_stylebox_override("normal", _bg(c_card, c_border))
	tab.add_theme_stylebox_override("hover", _bg(c_card, c_sel))
	tab.add_theme_stylebox_override("pressed", _bg(c_card, c_sel))
	tab.add_theme_stylebox_override("focus", _bg(c_card, c_border))
	var on := _bg(c_card.lightened(0.08), c_sel)
	on.set_border_width_all(4)
	tab.add_theme_stylebox_override("checked", on)
	var ic := TextureRect.new()
	ic.name = "TabIcon"
	ic.texture = icon
	ic.ignore_texture_size = true
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var half := size * TAB_ICON_RATIO / 2.0
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -half
	ic.offset_right = half
	ic.offset_top = -half
	ic.offset_bottom = half
	tab.add_child(ic)
	return tab


## Nama+isi node teks yang TERCETAK di tile. Badge angka dikecualikan (angka
## kuantitas diizinkan kriteria user; label kata tidak).
static func label_nodes(tile: Control) -> Array[String]:
	var out: Array[String] = []
	var stack: Array = [tile]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
			if c.name == BADGE_LABEL:
				continue
			if c is Label:
				var l := c as Label
				if l.visible and l.text.strip_edges() != "":
					out.append(String(c.name) + "='" + l.text + "'")
	return out


## Audit sekumpulan tile: berapa yang masih punya label kata + rasio ikon nyata
## (diukur dari ukuran node hasil layout, bukan dari konstanta).
static func audit(tiles: Array, menu: String, tab: String) -> Dictionary:
	var with_text: Array[String] = []
	var ratios: Array[float] = []
	for t in tiles:
		var tile := t as Control
		if tile == null:
			continue
		var labels := label_nodes(tile)
		if not labels.is_empty():
			with_text.append(String(tile.name) + ":" + str(labels))
		var ic := tile.get_node_or_null(ICON_NAME) as Control
		if ic != null and tile.size.x > 0.0:
			ratios.append(ic.size.x / tile.size.x)
	var min_ratio := 100.0
	for r in ratios:
		min_ratio = minf(min_ratio, r)
	return {
		"menu": menu,
		"tab": tab,
		"tiles": tiles.size(),
		"with_text": with_text.size(),
		"detail": str(with_text),
		"icon_ratio": int(round(min_ratio * 100.0)) if not ratios.is_empty() else 0,
	}


## 1 = semua card tanpa label teks (rasio card berlabel 0%).
static func label_free_ratio(au: Dictionary) -> float:
	var n := int(au.get("tiles", 0))
	if n <= 0:
		return 0.0
	return 1.0 - float(int(au.get("with_text", 0))) / float(n)


static func _bg(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)  ## 8dp
	s.set_border_width_all(2)    ## 1dp
	s.border_color = border
	return s


static func _ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size  ## design px (1px = 0,5dp)
	ls.font_color = color
	return ls
