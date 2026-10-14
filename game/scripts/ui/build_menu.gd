extends Control
## BuildMenu — modal menu konstruksi (GAMEPLAY_FLOW.md §3 Frame 5, M3 #1).
## Pola Doomsday (BAG modal, docs/references/doomsday/FRAME_BY_FRAME.md F6):
## title + close X + grid of cards + detail panel kanan + tombol besar bawah.
##
## M3.7c — tata letak katalog ditiru dari game strategi nyata (CoC: tab ikon +
## grid TILE art-dominan; label kata hanya di chrome menu). Card KATALOG tidak
## lagi memuat teks: satu-satunya teks di tile = badge ANGKA kuantitas.
##
## Ukuran (design canvas 1280×720, 1px = 0,5dp — UI_UX_DESIGN.md §3):
##   modal 1088×544 (544×272dp), radius 12dp, border 1dp
##   TAB kategori 96×96 (48dp persegi) — IKON saja, tanpa label kata
##   TILE katalog 152×152 (76dp) — ikon 70% (106px) + badge angka
##   tombol BANGUN besar tinggi 48dp (UI_UX_DESIGN.md §4: tombol besar 48–56dp)
##
## Anggaran tinggi (dihitung dari node, verifikasi ui.menu_fit):
##   konten modal 544-2×16 = 512 → title 80 + tab 96 + 2×8 gap = 192
##   → area grid 320 = 2 baris tile 152 + gap 16 ✓ (M3.6: 3 baris card 128 +
##   2×16 = 416 > 320 → konten meluber 96px, kini diperbaiki)
## Anggaran lebar: konten 1056 → grid 4×152+3×16 = 656 | 16 | detail 360 = 1032 ✓
##
## Aturan: UI read-only — memanggil API sistem yang sama dengan gameplay
## (ProductionSystem.enqueue_construction — atomic, biaya dibayar saat enqueue).
## Hanya bangunan non-HQ yang tampil (HQ sudah ada & unik — upgrade via klik
## bangunan di arena, lihat HUD selection panel / Frame 4).

const DESIGN_W := 1280
const DESIGN_H := 720
## Layout dihitung dari lebar teks aktual (bukan asumsi): modal 1152 (576dp),
## konten 1056; grid 2 kolom = 1056-16-360 = 680 → card 332 (166dp) → area teks
## 332-16(isi)-96(ikon)-16(gap) = 204px → nama panjang 2 baris (autowrap) ✓ (M3.6).
## Tinggi: 560 (280dp) → body 464 → 3 baris card 128 + 2 gap = 416 ✓.
const MODAL_W := 1024   ## 512dp (batas dialog Material 560dp)
const MODAL_H := 560    ## 280dp (anggaran: title 96 + tab 96 + 2×8 + grid 320)
const TITLE_H := 80     ## 40dp
const GRID_COLS := 4    ## 4 kolom tile 112 = 224dp + 3 gap = 248dp (area grid 292dp)
const DETAIL_MIN_H := 392  ## mode narrow: tinggi minimum panel detail (konten 364 + margin)
const DETAIL_W := 360   ## 180dp — body 11dp muat tanpa terpotong (M3.6)
const BTN_BIG_H := 96   ## 48dp tombol besar

const C_PANEL := Color(0.043, 0.063, 0.125, 0.92)
const C_CARD := Color(0.055, 0.082, 0.16, 0.9)
const C_BORDER := Color(0.208, 0.816, 1.0, 0.55)
const C_BORDER_SEL := Color(0.208, 0.816, 1.0, 1.0)
const C_TEXT := Color(0.918, 0.965, 1.0, 1.0)
const C_MUTED := Color(0.62, 0.70, 0.80, 1.0)
const C_ACCENT := Color(0.208, 0.816, 1.0, 1.0)
const C_WARN := Color(1.0, 0.72, 0.30, 1.0)
const C_DIM := Color(0.45, 0.45, 0.50, 0.85)
const C_DIMMED_BG := Color(0.043, 0.063, 0.125, 0.55)

var _dim: ColorRect
var _modal: PanelContainer
var _grid: GridContainer
var _body_h: HBoxContainer     ## body mode WIDE (grid | detail berdampingan)
var _body_scroll: ScrollContainer  ## body mode NARROW (grid di atas detail, bisa digulir)
var _body_v: VBoxContainer
var _card_scroll: ScrollContainer
var _detail_panel: Panel
var _narrow := false           ## mode sempit aktif? (dipilih dari lebar NYATA)
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_cat: Label
var _detail_effect: Label
var _detail_cost: Label
var _detail_time: Label
var _detail_status: Label
var _res_strip: Label  ## strip resource di baris judul (M3.6)
var _vbox: VBoxContainer   ## host konten modal (diisi _ready)
var _tab_row: HBoxContainer
var _tab_group := ButtonGroup.new()
var _tabs: Dictionary = {}   ## kategori -> Button (tab IKON, tanpa label kata)
var _tab_defs: Array[Dictionary] = []
var _active_cat: StringName = &"all"
var _build_btn: Button
var _close_btn: Button
var _cards: Dictionary = {}        ## def_id -> Button (tile katalog, tanpa teks)
var _card_cat: Dictionary = {}     ## def_id -> StringName kategori
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
	## Anchor CENTER — modal selalu di tengah SEMUA aspek layar (HUD full-rect
	## design space melebar di 19.5:9/20:9; posisi absolut design akan geser).
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

	# --- title bar: "BUILD" + close X (48dp touch target) ---
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0, TITLE_H)
	title_row.add_theme_constant_override("separation", 16)
	_vbox.add_child(title_row)
	var title := Label.new()
	title.label_settings = _ls(32, C_TEXT)
	title.text = "BANGUN"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	## strip resource di modal (pola standar dialog konteks: chip HUD di balik
	## dim tertutup modal → pemain tetap melihat ENERGI/MINERAL saat memilih)
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

	# --- baris tab kategori: IKON saja (48dp persegi, tanpa label kata) ---
	_build_tabs()

	## Body punya DUA mode — temuan audit M3 #8 (foto portrait 360dp): modal
	## 512dp terpotong & kartu keluar rect panel. Mode dipilih dari lebar NYATA
	## (`_fit_modal()`), bukan asumsi device:
	##   WIDE   = grid | detail berdampingan (HBox) — landscape/tablet.
	##   NARROW = grid di ATAS detail di dalam scroll vertikal — portrait.
	_body_h = HBoxContainer.new()
	_body_h.name = "Body"
	_body_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_h.add_theme_constant_override("separation", 16)
	_vbox.add_child(_body_h)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "BodyScroll"
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.visible = false
	_vbox.add_child(_body_scroll)
	_body_v = VBoxContainer.new()
	_body_v.name = "BodyStack"
	_body_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_v.add_theme_constant_override("separation", 16)
	_body_scroll.add_child(_body_v)

	## Grid di dalam ScrollContainer: anggaran 320px memuat 2 baris tile 152;
	## bila data bertambah, katalog menggeser (bukan meluber keluar modal).
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "CardScroll"
	_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_h.add_child(_card_scroll)

	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = GRID_COLS  ## M3.7c: 4 kolom tile 152 (pola katalog CoC)
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_card_scroll.add_child(_grid)

	_detail_panel = Panel.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.custom_minimum_size = Vector2(DETAIL_W, 0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dstyle := StyleBoxFlat.new()
	dstyle.bg_color = C_CARD
	dstyle.set_corner_radius_all(16)
	dstyle.set_border_width_all(2)
	dstyle.border_color = C_BORDER
	dstyle.set_content_margin_all(16)
	_detail_panel.add_theme_stylebox_override("panel", dstyle)
	_body_h.add_child(_detail_panel)
	var dv := VBoxContainer.new()
	dv.set_anchors_preset(Control.PRESET_FULL_RECT)
	## 4dp: total konten detail (ikon 64 + nama 36 + kategori 30 + efek 60 +
	## biaya 32 + waktu 30 + tombol 88 + status) = 340 + 6×4 = 364 ≤ 392 (panel)
	dv.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(dv)
	## Header detail: art kecil + nama/kategori (hemat tinggi — anggaran 320px)
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
	_detail_cat = Label.new()
	_detail_cat.label_settings = _ls(22, C_MUTED)  ## 11dp
	hcol.add_child(_detail_cat)  ## di bawah nama (header detail ringkas)
	## Blok efek = area yang BERGESER bila panjang (temuan foto 05: teks stats
	## kapal + tombol PRODUKSI keluar dari modal). Dengan ScrollContainer,
	## tinggi panel detail tetap dan tombol aksi SELALU di dalam panel.
	var eff_scroll := ScrollContainer.new()
	eff_scroll.name = "DetailScroll"
	eff_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eff_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(eff_scroll)
	_detail_effect = Label.new()
	_detail_effect.label_settings = _ls(24, C_TEXT)  ## 12dp
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff_scroll.add_child(_detail_effect)
	_detail_cost = Label.new()
	_detail_cost.label_settings = _ls(26, C_WARN)  ## 13dp
	dv.add_child(_detail_cost)
	_detail_time = Label.new()
	_detail_time.label_settings = _ls(22, C_MUTED)  ## 11dp
	dv.add_child(_detail_time)
	_build_btn = Button.new()
	_build_btn.name = "BuildButton"
	_build_btn.custom_minimum_size = Vector2(0, 88)  ## 44dp — lebih ringkas, tetap > 40dp
	_build_btn.text = "BANGUN"
	_build_btn.add_theme_font_size_override("font_size", 28)
	_build_btn.pressed.connect(_on_build_pressed)
	dv.add_child(_build_btn)
	_detail_status = Label.new()
	_detail_status.name = "DetailStatus"
	_detail_status.label_settings = _ls(22, C_ACCENT)  ## 11dp
	_detail_status.visible = false  ## hanya tampil saat ada pesan (hemat tinggi)
	dv.add_child(_detail_status)

	_build_cards()
	_refresh()


func _build_tabs() -> void:
	## Tab kategori = IKON saja (menu tidak semua elemennya berlabel — pola CoC).
	_tab_defs = []
	var cats: Array[StringName] = [&"all"]
	var seen := {}
	for id in _defs_order():
		var c := StringName(GameData.get_building_def(id).category)
		if not seen.has(c):
			seen[c] = true
			cats.append(c)
	for c in cats:
		_tab_defs.append({"id": c, "icon": _tab_icon(c), "tip": _cat_text(String(c))})
	_tab_row = HBoxContainer.new()
	_tab_row.name = "CategoryTabs"
	_tab_row.custom_minimum_size = Vector2(0, CatalogTile.TAB)
	_tab_row.add_theme_constant_override("separation", 16)
	_vbox.add_child(_tab_row)
	for t in _tab_defs:
		var tab: Button = CatalogTile.make_tab(_load_icon(String(t["icon"])), String(t["tip"]),
			_tab_group, C_BORDER, C_CARD, C_BORDER_SEL)
		tab.name = "Tab_" + String(t["id"])
		tab.pressed.connect(_on_tab_pressed.bind(StringName(t["id"])))
		_tab_row.add_child(tab)
		_tabs[StringName(t["id"])] = tab
	if _tabs.has(&"all"):
		(_tabs[&"all"] as Button).button_pressed = true


func _defs_order() -> Array[StringName]:
	## Urutan bangunan katalog: unlocked via ProgressionSystem, HQ dikecualikan.
	var out: Array[StringName] = []
	var pr := SystemRefs.progression_system()
	if pr == null:
		return out
	for id in pr.unlocked:
		var def := GameData.get_building_def(id)
		if def != null and def.category != "hq":
			out.append(id)
	return out


func _build_cards() -> void:
	## Tile katalog: ikon 70% + badge angka, TANPA label teks di tile
	## (nama/biaya/kategori hanya di panel detail — kriteria user M3.7c).
	var bs := SystemRefs.building_system()
	for id in _defs_order():
		var def := GameData.get_building_def(id)
		var tile: Button = CatalogTile.make_tile(_load_icon(_icon_for(id)),
			bs.count_of(id) if bs != null else 0,
			def.display_name, _tab_group, C_BORDER, C_CARD, C_BORDER_SEL, C_TEXT)
		tile.name = "Tile_" + String(id)
		tile.pressed.connect(_on_card_pressed.bind(id))
		_cards[id] = tile
		_card_cat[id] = StringName(def.category)
		_grid.add_child(tile)
		_def_order.append(id)
	_apply_tab()
	_fit_modal()
	resized.connect(_fit_modal)  ## rotasi/aspect berubah → modal menyesuaikan


func _on_tab_pressed(cat: StringName) -> void:
	_active_cat = cat
	_apply_tab()


func _apply_tab() -> void:
	for id in _cards.keys():
		(_cards[id] as Control).visible = _active_cat == &"all" or _card_cat[id] == _active_cat
	_audit_cards()


## Angka badge kuantitas pada tile (0 = badge tidak tampil) — untuk QA & test.
func qty_of(def_id: StringName) -> int:
	if not _cards.has(def_id):
		return 0
	return CatalogTile.qty_of(_cards[def_id])


func get_active_category() -> StringName:
	## Kategori/tab yang sedang aktif (dipakai gate & suite input M3 #8).
	return _active_cat


## Audit card katalog (kriteria user: mayoritas card TANPA label teks).
## Mengembalikan hasil CatalogTile.audit atas tile yang SEDANG tampil.
func audit_cards() -> Dictionary:
	return _audit_cards()


func _audit_cards() -> Dictionary:
	var shown: Array = []
	for id in _cards.keys():
		if (_cards[id] as Control).visible:
			shown.append(_cards[id])
	var au: Dictionary = CatalogTile.audit(shown, "build", String(_active_cat))
	for id in _cards.keys():
		var tile := _cards[id] as Control
		if not tile.visible:
			continue
		var labels := CatalogTile.label_nodes(tile)
		QaMarkers.marker("CARD", "TILE", {"menu": "build", "id": String(id),
			"text_nodes": labels.size(), "labels": str(labels),
			"qty": CatalogTile.qty_of(tile),
			"icon_ratio": CatalogTile.icon_ratio() * 100.0})
	QaMarkers.marker("CARD", "SUMMARY", {"menu": "build", "tab": String(_active_cat),
		"tiles": au["tiles"], "with_text": au["with_text"],
		"label_free_pct": int(round(CatalogTile.label_free_ratio(au) * 100.0)),
		"icon_ratio": au["icon_ratio"],
		## Ukuran NYATA (temuan pemain "card terlalu besar"): tile px + dp + rect grid.
		"tile_px": int(CatalogTile.TILE), "tile_dp": int(CatalogTile.TILE / 2.0),
		"grid": "%dx%d" % [int(_grid.size.x), int(_grid.size.y)]})
	return au


func _audit_layout_deferred() -> void:
	## Tumpukan/ukuran kartu diukur SETELAH container settle (2 frame) — rect
	## sebelum itu masih nol/posisi lama (pelajaran M3.7c & M3 #5).
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible:
		return
	var shown: Array = []
	for id in _cards.keys():
		if (_cards[id] as Control).visible:
			shown.append(_cards[id])
	var au: Dictionary = CatalogTile.audit_layout(shown, self, GRID_COLS)
	QaMarkers.marker("CARD", "LAYOUT", {"menu": "build", "tab": String(_active_cat),
		"count": au["count"], "uniform": au["uniform"], "inside_panel": au["inside_panel"],
		"inside_screen": au["inside_screen"], "cols": _grid.columns, "narrow": _narrow,
		"gap_min": au["gap_min"], "gap_max": au["gap_max"], "tile_px": au["tile_px"],
		"ok": au["ok"], "pairs": str(au["pairs"])})


## ---------------------------------------------------------- responsif ----
const MARGIN_PX := 32.0    ## 16dp margin tepi layar (standar Material dialog)


func _fit_modal() -> void:
	## Ukuran modal dihitung dari RUANG NYATA di design space (bukan asumsi
	## device). Aturan Material: dialog ≤ 560dp & ≥ 16dp dari tepi layar —
	## kenyataan portrait 360dp (design 720px) memaksa lebar mengecil, dan
	## `inside_panel` audit M3 #8 membuktikan modal lama 1024px terpotong.
	var avail := size - Vector2(MARGIN_PX * 2.0, MARGIN_PX * 2.0)
	if avail.x < 240.0 or avail.y < 240.0:
		return  ## belum ter-layout (boot) — pertahankan ukuran default
	var w := minf(MODAL_W, maxf(avail.x, 272.0))  ## 272px = 2 kolom kartu (minimum teknis)
	var h := minf(MODAL_H, maxf(avail.y, 320.0))
	_modal.custom_minimum_size = Vector2(w, h)
	_modal.offset_left = -w / 2.0
	_modal.offset_right = w / 2.0
	_modal.offset_top = -h / 2.0
	_modal.offset_bottom = h / 2.0
	var content_w := w - 32.0  ## padding panel 16dp kiri+kanan
	var wide_need := float(GRID_COLS) * CatalogTile.TILE + float(GRID_COLS - 1) * 16.0 \
		+ 16.0 + DETAIL_W
	var narrow := content_w < wide_need
	var cols := GRID_COLS
	if narrow:
		## Kolom sebanyak yang MUAT (kartu tetap TILE px/56dp, tidak mengecil).
		cols = clampi(int((content_w + 16.0) / (CatalogTile.TILE + 16.0)), 2, GRID_COLS)
	_grid.columns = cols
	_set_body_mode(narrow)
	_narrow = narrow
	QaMarkers.marker("CARD", "MODAL", {"menu": "build", "w": snappedf(w, 0.5),
		"h": snappedf(h, 0.5), "cols": cols, "narrow": narrow,
		"avail": "%.0fx%.0f" % [avail.x, avail.y], "content_w": snappedf(content_w, 0.5)})


func _set_body_mode(narrow: bool) -> void:
	## Reparent isi body (node tidak dibuat ulang → state seleksi & sinyal aman).
	var grid_parent: Node = _body_v if narrow else _card_scroll
	if _grid.get_parent() != grid_parent:
		_grid.reparent(grid_parent, false)
	var detail_parent: Node = _body_v if narrow else _body_h
	if _detail_panel != null and _detail_panel.get_parent() != detail_parent:
		_detail_panel.reparent(detail_parent, false)
	_body_h.visible = not narrow
	_body_scroll.visible = narrow
	if narrow:
		## Di dalam VBox→ScrollContainer: detail butuh tinggi eksplisit (anaknya
		## anchored full-rect, jadi panel tidak bisa menyusut ke konten).
		_detail_panel.custom_minimum_size = Vector2(0, DETAIL_MIN_H)
		_detail_panel.size_flags_vertical = Control.SIZE_FILL
		_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_detail_panel.custom_minimum_size = Vector2(DETAIL_W, 0)
		_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grid.size_flags_horizontal = Control.SIZE_FILL


func is_narrow_layout() -> bool:
	## Dipakai gate/audit: mode body aktual (dari data layout, bukan asumsi).
	return _narrow


func modal_rect() -> Rect2:
	return _modal.get_global_rect() if _modal != null else Rect2()


func _find_base_scene() -> Node:
	## Arena (BaseScene) pemilik mode penempatan — dicari dari pohon node nyata.
	var n: Node = self
	while n != null:
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("base_scene.gd"):
			return n
		n = n.get_parent()
	return null


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  ## modal blok klik ke arena
	_fit_modal()          ## ukuran dari ruang nyata (M3 #8: portrait tidak terpotong)
	_refresh()
	_audit_cards()
	_audit_layout_deferred()
	if _selected == &"" and _def_order.size() > 0:
		select(_def_order[0])
	QaMarkers.marker("UI", "MENU", {"event": "open", "kind": "build"})


func close() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	QaMarkers.marker("UI", "MENU", {"event": "close", "kind": "build"})


func is_open() -> bool:
	return visible


func card_count() -> int:
	return _cards.size()


func get_selected() -> StringName:
	return _selected


func select(def_id: StringName) -> void:
	## Pilih bangunan di grid → update detail panel.
	var def := GameData.get_building_def(def_id)
	if def == null:
		return
	_selected = def_id
	for id in _cards.keys():
		if id != def_id:
			(_cards[id] as Button).button_pressed = false
	if _active_cat != &"all" and _card_cat.get(def_id, &"") != _active_cat:
		_on_tab_pressed(StringName(def.category))  ## tile wajib tampil agar terpilih
	if _cards.has(def_id):
		(_cards[def_id] as Button).button_pressed = true
	_detail_icon.texture = _load_icon(_icon_for(def_id))
	_detail_name.text = def.display_name
	_detail_cat.text = "KATEGORI   " + _cat_text(def.category)  ## label field (M3.7)
	_detail_effect.text = _effect_text(def)
	_refresh()


## Tombol BUILD besar ditekan — enqueue konstruksi (atomic via ProductionSystem).
## Mengembalikan true jika konstruksi berhasil di-enqueue.
func press_build() -> bool:
	var def := GameData.get_building_def(_selected)
	var bs := SystemRefs.building_system()
	var ps := SystemRefs.production_system()
	if def == null or bs == null or ps == null:
		return false
	if not Economy.can_afford(def.base_cost):
		_detail_status.visible = true
		_detail_status.text = tr("Sumber daya tidak cukup")
		_detail_status.label_settings.font_color = C_WARN
		EventBus.ui_message.emit(tr("Sumber daya tidak cukup untuk ") + def.display_name, "warning")
		return false
	## M3 #9 — LOGIKA BUILD GAME STRATEGI: biaya TIDAK dibayar di sini. Katalog
	## ditutup dan arena masuk MODE PENEMPATAN (hantu) — pemain meletakkan lalu
	## KONFIRMASI. Tanpa arena (unit test headless) dipakai jalur langsung supaya
	## kontrak lama `enqueue_construction` tetap teruji.
	var scene := _find_base_scene()
	if scene != null and scene.has_method("enter_placement"):
		close()
		EventBus.placement_requested.emit(_selected)
		QaMarkers.marker("UI", "BUILD_REQUEST", {"id": _selected, "mode": "placement"})
		return true
	var pos := bs.next_free_position(def.footprint)
	if ps.enqueue_construction(_selected, pos):
		_detail_status.visible = true
		_detail_status.text = "Pembangunan dimulai: %s" % def.display_name
		_detail_status.label_settings.font_color = C_ACCENT
		QaMarkers.marker("UI", "BUILD", {"id": _selected, "pos": "%d,%d" % [int(pos.x), int(pos.z)]})
		_refresh()
		return true
	_detail_status.visible = true
	_detail_status.text = "Antrian pembangunan gagal"
	_detail_status.label_settings.font_color = C_DIM
	return false


func _on_build_pressed() -> void:
	press_build()


func _on_card_pressed(def_id: StringName) -> void:
	select(def_id)
	QaMarkers.marker("UI", "SELECT", {"kind": "build_card", "id": def_id})


# ------------------------------------------------------------- refresh ----
func _refresh() -> void:
	## Perbarui badge angka di tile (satu-satunya teks di tile) + panel detail.
	_update_res_strip()
	var bs := SystemRefs.building_system()
	for id in _cards.keys():
		CatalogTile.set_qty(_cards[id], bs.count_of(id) if bs != null else 0)
	var def := GameData.get_building_def(_selected)
	if def == null:
		return
	var affordable := Economy.can_afford(def.base_cost)
	_detail_cost.text = "BIAYA   " + _cost_text(def.base_cost)
	_detail_cost.label_settings.font_color = C_WARN if affordable else C_DIM
	_detail_time.text = "WAKTU BANGUN   %ds" % int(round(def.build_time_ticks / float(TimeSystem.TICKS_PER_SECOND)))
	## M3 #7: tombol BANGUN tidak disabled — tap harus selalu menjawab, alasan
	## ditulis di baris SYARAT + toast (temuan pemain: "tidak bisa diklik").
	_build_btn.disabled = false
	_build_btn.modulate = Color(1, 1, 1, 1) if affordable else Color(1.0, 1.0, 1.0, 0.82)
	_audit_cards()


func _update_res_strip() -> void:
	if _res_strip == null:
		return
	_res_strip.text = "ENERGI %d/%d   MINERAL %d/%d" % [
		Economy.get_amount(&"energy"), Economy.get_cap(&"energy"),
		Economy.get_amount(&"minerals"), Economy.get_cap(&"minerals"),
	]


# ------------------------------------------------------------- helpers ----
func _tab_icon(cat: StringName) -> String:
	## Ikon tab per kategori (ikon saja — tanpa label kata, pola CoC).
	match String(cat):
		"all": return "grid"
		"economy": return "crate"
		"production": return "factory"
		"defense": return "fort"
		_: return "grid"


func _cat_text(cat: String) -> String:
	## M3.5: label kategori bangunan — Bahasa Indonesia
	match cat:
		"hq": return "PUSAT"
		"economy": return "EKONOMI"
		"production": return "PRODUKSI"
		"defense": return "PERTAHANAN"
		_: return cat.to_upper()


func _res_text(res_id: String) -> String:
	## M3.5: label sumber daya — Bahasa Indonesia
	match res_id:
		"energy": return "ENERGI"
		"minerals": return "MINERAL"
		_: return res_id.to_upper()


func _effect_text(def: BuildingDef) -> String:
	var lines: Array[String] = []
	if def.produces != &"":
		lines.append("+%d %s/detik (Lv1)" % [def.get_production_for_level(1), _res_text(def.produces)])
	for res_id in def.storage_bonus.keys():
		lines.append("+%d %s simpanan" % [int(def.storage_bonus[res_id]), _res_text(String(res_id))])
	if def.weapon_id != &"":
		lines.append("Senjata: %s" % def.weapon_id)
	if def.shield_pool > 0:
		lines.append("Perisai %d" % def.get_shield_pool_for_level(1))
	lines.append("HP %d" % def.max_hp)
	return "\n".join(lines)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if int(cost.get("energy", 0)) > 0:
		parts.append("E%d" % int(cost.get("energy", 0)))
	if int(cost.get("minerals", 0)) > 0:
		parts.append("M%d" % int(cost.get("minerals", 0)))
	return " ".join(parts) if not parts.is_empty() else "GRATIS"


var _icon_map := {
	&"command_core": "command",
	&"energy_reactor": "reactor",
	&"mineral_extractor": "extractor",
	&"fighter_hangar": "hangar",
	&"laser_turret": "turret",
	&"shield_generator": "shield",
}


func _icon_for(id: StringName) -> String:
	return _icon_map.get(id, "command")


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
	## M3 #7: ikon SVG asli (satu pemuat untuk seluruh game via UiTheme).
	return UiTheme.get_icon(id)
