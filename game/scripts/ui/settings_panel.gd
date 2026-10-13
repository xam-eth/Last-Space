class_name SettingsPanel
extends Control
## SettingsPanel — panel PENGATURAN (M3 #5: audio / tampilan / ukuran UI /
## bahasa). Komponen TUNGGAL dipakai menu utama dan pause menu (satu sumber,
## satu audit — pola CatalogTile/UiTheme).
##
## Tata letak (mobile-first landscape 16:9–21:9; UI_UX_DESIGN.md §3/§8):
##   dialog ≤ 560dp (batas dialog Material), dua kolom di layar lebar
##   (label kiri, kontrol kanan) supaya baris tidak terlalu lebar untuk jempol;
##   setiap kontrol tinggi ≥ 48dp (touch target), slider HSlider 48dp.
##   Di layar sempit (portrait/lebar < 900 design px) kolom menjadi SATU (stack).
##
## Aturan label (kriteria user 2026-10-13): ini MENU → kontrol berlabel; nilai
## numerik (persen) dan tombol segmen punya teks. Ikon hanya pendamping.
##
## Semua perubahan langsung diterapkan lewat SettingsSystem (AudioServer bus,
## DisplayServer, HUD scale, TranslationServer) + tersimpan; panel tidak
## menyimpan salinan nilai sendiri (satu sumber kebenaran).

const PANEL_W := 1040      ## 520dp (< 560dp batas dialog Material)
const PANEL_MAX_H := 640   ## 320dp (layar 360dp − margin 16dp atas/bawah)
const ROW_H := 96          ## 48dp — baris kontrol
const SLIDER_H := 48       ## 24dp tinggi slider (thumb 48dp area sentuh)
const BTN_H := 96          ## 48dp
const MARGIN := 32         ## 16dp
const GAP := 16            ## 8dp
const TWO_COL_MIN_W := 900 ## ≥450dp: dua kolom (label | kontrol)

var _panel: PanelContainer
var _body: VBoxContainer
var _head: HBoxContainer
var _foot: HBoxContainer
var _scroll: ScrollContainer
var _sections: VBoxContainer
var _status: Label
var _close_btn: Button
var _reset_btn: Button
var _language_note: Label
var _sliders: Dictionary = {}      ## key -> HSlider
var _values: Dictionary = {}       ## key -> Label (persen)
var _segments: Dictionary = {}     ## group -> {value -> Button}
var _rows: Array[Control] = []
var _fit: Dictionary = {}


func _ready() -> void:
	name = "SettingsPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  ## penuh layar
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	EventBus.settings_changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_apply_fit)
	_sync_from_settings()
	call_deferred("_audit_overlap", "open")
	_fit_when_ready()


# ------------------------------------------------------------------ build ----
func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	## Dialog di tengah layar; ukuran mengikuti minimum size konten, tumbuh dari
	## pusat (bukan dari pojok kiri-atas) supaya benar-benar center di semua device.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.C_MODAL))
	add_child(_panel)

	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override("separation", GAP)
	_panel.add_child(_body)

	# --- judul + tombol tutup berlabel (chrome menu) ---
	var head := HBoxContainer.new()
	_head = head
	head.name = "Header"
	head.add_theme_constant_override("separation", GAP)
	_body.add_child(head)
	var title := Label.new()
	title.name = "Title"
	title.label_settings = UiTheme.ls(44, UiTheme.C_TEXT)
	title.text = tr("PENGATURAN")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	_close_btn = _button(tr("TUTUP"), UiTheme.BTN_H, "close")
	_close_btn.name = "CloseButton"
	_close_btn.pressed.connect(press_close)
	head.add_child(_close_btn)
	_rows.append(_close_btn)

	## Bagian tengah (seksi + baris) bisa digeser: layar landscape 360dp hanya
	## muat ~4 baris 48dp — header/footer tetap, isi di-scroll (pola M3.7c).
	_scroll = ScrollContainer.new()
	_scroll.name = "SettingsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	_sections = VBoxContainer.new()
	_sections.name = "Sections"
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_theme_constant_override("separation", GAP)
	_scroll.add_child(_sections)

	_add_section("AUDIO")
	_add_slider("master_volume", "Volume utama", UiTheme.C_ACCENT)
	_add_slider("sfx_volume", "Efek suara", UiTheme.C_OK)
	_add_slider("music_volume", "Musik", UiTheme.C_MUTED)

	_add_section("TAMPILAN")
	_add_toggle("fullscreen", "Layar penuh")
	_add_segments("hud_scale", "Ukuran UI", [
		{"value": 0.85, "text": "Kecil"}, {"value": 1.0, "text": "Normal"},
		{"value": 1.15, "text": "Besar"},
	])

	_add_section("BAHASA")
	_add_segments("language", "Bahasa", [
		{"value": "id", "text": "Indonesia"}, {"value": "en", "text": "English"},
	])
	_language_note = Label.new()
	_language_note.name = "LanguageNote"
	_language_note.label_settings = UiTheme.ls(22, UiTheme.C_MUTED)
	_language_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_language_note.text = tr("Terjemahan EN: menu & pengaturan; HUD/katalog masih ID (dilaporkan)")
	_sections.add_child(_language_note)

	# --- footer: status + reset + simpan/tutup ---
	var foot := HBoxContainer.new()
	_foot = foot
	foot.name = "Footer"
	foot.add_theme_constant_override("separation", GAP)
	_body.add_child(foot)
	_status = Label.new()
	_status.name = "Status"
	_status.label_settings = UiTheme.ls(22, UiTheme.C_ACCENT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.clip_text = true  ## anti-tumpuk dengan tombol reset (temuan gate)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(0, 0)
	_status.text = tr("Pengaturan tersimpan")
	_status.visible = false
	foot.add_child(_status)
	_reset_btn = _button(tr("Kembalikan default"), UiTheme.BTN_H, "warning")
	_reset_btn.name = "ResetButton"
	_reset_btn.pressed.connect(press_reset)
	foot.add_child(_reset_btn)
	_rows.append(_reset_btn)

	_fit_when_ready()


## Tombol standar (UiTheme) + ikon opsional; label tetap teks (aturan menu).
func _button(text: String, height: int, icon_id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, height)
	if icon_id != "":
		b.icon = UiTheme.get_icon(icon_id)
		b.add_theme_constant_override("icon_max_width", 40)
	UiTheme.style_button(b, height >= UiTheme.BTN_PRIMARY_H)
	return b


func _add_section(text: String) -> void:
	_sections.add_child(_section_label(text))


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.name = "Section_" + text.replace(" ", "")
	l.label_settings = UiTheme.ls(26, UiTheme.C_ACCENT)
	l.text = tr(text)
	return l


## Baris kontrol: label kiri (≥ 240 design px) + kontrol kanan (expand).
func _make_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + label_text.replace(" ", "")
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_constant_override("separation", GAP)
	_sections.add_child(row)
	var l := Label.new()
	l.label_settings = UiTheme.ls(24, UiTheme.C_TEXT)
	l.text = tr(label_text)
	l.custom_minimum_size = Vector2(240, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_rows.append(l)
	return row


func _add_slider(key: String, label_text: String, color: Color) -> void:
	var row := _make_row(label_text)
	var slider := HSlider.new()
	slider.name = "Slider_" + key
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(200, SLIDER_H)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	var val := Label.new()
	val.name = "Value_" + key
	val.label_settings = UiTheme.ls(24, color)
	val.custom_minimum_size = Vector2(96, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	_sliders[key] = slider
	_values[key] = val
	_rows.append(slider)


func _add_toggle(key: String, label_text: String) -> void:
	var row := _make_row(label_text)
	var btn := _button("", BTN_H, "grid")
	btn.name = "Toggle_" + key
	btn.toggle_mode = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_toggle_pressed.bind(key))
	row.add_child(btn)
	_segments[key] = btn
	_rows.append(btn)


func _add_segments(key: String, label_text: String, options: Array) -> void:
	var row := _make_row(label_text)
	## Satu ButtonGroup BERSAMA untuk seluruh pilihan baris → eksklusivitas radio
	## benar-benar dijamin oleh kontrol (bukan hanya oleh _sync_from_settings).
	var group := ButtonGroup.new()
	for opt in options:
		var btn := _button(String(opt["text"]), BTN_H, "")
		btn.name = "Seg_%s_%s" % [key, str(opt["value"])]
		btn.toggle_mode = true
		btn.button_group = group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_segment_pressed.bind(key, opt["value"]))
		row.add_child(btn)
		_rows.append(btn)
		if not _segments.has(key):
			_segments[key] = {}
		_segments[key][opt["value"]] = btn


# ---------------------------------------------------------------- perilaku ---
func _sync_from_settings() -> void:
	for key in _sliders.keys():
		(_sliders[key] as HSlider).set_value_no_signal(SettingsSystem.get_float(key))
		_update_value_label(key)
	if _segments.has("fullscreen"):
		var fs: Button = _segments["fullscreen"]
		fs.set_pressed_no_signal(SettingsSystem.get_bool("fullscreen"))
		fs.text = "Layar penuh: %s" % ("AKTIF" if fs.button_pressed else "MATI")
	for key in ["hud_scale", "language"]:
		if not _segments.has(key):
			continue
		var v = SettingsSystem.get_value(key)
		for opt_val in (_segments[key] as Dictionary).keys():
			var b: Button = _segments[key][opt_val]
			var on: bool = (is_same(opt_val, v))
			b.set_pressed_no_signal(on)
			b.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0.75)


func is_same(a, b) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)


func _update_value_label(key: String) -> void:
	if not _values.has(key):
		return
	var pct := int(round(SettingsSystem.get_float(key) * 100.0))
	(_values[key] as Label).text = "%d%%" % pct


func _on_slider_changed(value: float, key: String) -> void:
	SettingsSystem.set_value(key, value)
	_update_value_label(key)
	## Umpan balik bunyi memakai bus yang sedang diatur (slider Musik → dengarkan
	## di bus Musik, jadi pengguna langsung mengukur hasilnya).
	AudioSystem.play("ui_confirm" if key == "music_volume" else "ui_click")


func _on_toggle_pressed(key: String) -> void:
	var btn: Button = _segments[key]
	SettingsSystem.set_value(key, btn.button_pressed)
	## Platform bisa MENOLAK permintaan (fullscreen browser butuh gesture
	## pengguna) → nilai pengaturan disamakan dengan mode nyata dan tombol
	## di-sync ulang supaya UI tidak berbohong (temuan test M3 #5).
	_sync_from_settings()
	var on := SettingsSystem.get_bool(key)
	AudioSystem.ui_confirm()
	_flash_status("%s %s" % [tr("Layar penuh"), "AKTIF" if on else "MATI"])


func _on_segment_pressed(key: String, value) -> void:
	SettingsSystem.set_value(key, value)
	AudioSystem.ui_click()
	_sync_from_settings()
	_flash_status("%s: %s" % [tr("Ukuran UI") if key == "hud_scale" else tr("Bahasa"),
		String(value)])


func press_reset() -> void:
	SettingsSystem.reset_defaults()
	_sync_from_settings()
	AudioSystem.ui_cancel()
	_flash_status(tr("Pengaturan dikembalikan ke default"))
	QaMarkers.marker("SET", "PANEL_RESET", SettingsSystem.snapshot())


func press_close() -> void:
	AudioSystem.ui_cancel()
	close()


func _flash_status(text: String) -> void:
	_status.text = text
	_status.visible = true


func _on_settings_changed(key: String, _value) -> void:
	if key in _sliders:
		(_sliders[key] as HSlider).set_value_no_signal(SettingsSystem.get_float(key))
		_update_value_label(key)
	if key == "hud_scale":
		## HUD scale mengubah ruang lokal panel (induk di-scale) → ukuran dialog
		## dihitung ulang supaya tetap ≤560dp & di dalam layar.
		_apply_fit()
		_audit_overlap("hud_scale")


## API publik (opsional dipakai test/gate): ubah nilai dari luar panel.
func set_slider(key: String, value: float) -> void:
	if _sliders.has(key):
		(_sliders[key] as HSlider).value = value  ## memicu value_changed → set_value


func press_segment(key: String, value) -> void:
	_on_segment_pressed(key, value)


func press_toggle(key: String) -> void:
	var b: Button = _segments[key]
	b.button_pressed = not b.button_pressed
	_on_toggle_pressed(key)


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_from_settings()
	_status.visible = false
	_audit_overlap("open")
	QaMarkers.marker("SET", "PANEL_OPEN", _panel_state())


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	QaMarkers.marker("SET", "PANEL_CLOSE", {})


func is_open() -> bool:
	return visible


func get_status_text() -> String:
	return _status.text if _status != null else ""


func get_panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()


func _panel_state() -> Dictionary:
	return {
		"values": SettingsSystem.snapshot(),
		"rect": [int(_panel.get_global_rect().position.x), int(_panel.get_global_rect().position.y),
			int(_panel.get_global_rect().size.x), int(_panel.get_global_rect().size.y)],
		"rows": _rows.size(),
	}


# ------------------------------------------------------------------ layout ---
func _apply_fit() -> void:
	## Lebar dialog ≤ 560dp & tidak melebihi layar (portrait 360dp diuji): kalau
	## tidak muat, panel menyusut dan baris kontrol menjadi satu kolom (stack).
	var vp := _viewport_size()
	if vp == Vector2.ZERO:
		_fit = {"fit": false, "pending": true}
		_on_resized()
		return
	var max_w: float = minf(PANEL_W, maxf(0.0, vp.x - 2.0 * MARGIN))
	var narrow := vp.x < TWO_COL_MIN_W
	## Lebar TOTAL panel = custom_minimum_size + margin stylebox (kiri+kanan) —
	## diukur di runtime: 1040 konten + 64 margin = 1104 px (552dp) meleset dari
	## target 520dp. Jadi target dikurangi margin dulu.
	var pad := 2.0 * MARGIN
	_panel.custom_minimum_size = Vector2(maxf(0.0, max_w - pad), 0)
	## Baris kontrol hidup di dalam _sections (ScrollContainer), BUKAN _body —
	## iterasi harus ke sana, kalau tidak mode sempit tidak pernah mengecilkan
	## label (temuan foto portrait: panel 698 design px > batas 656).
	for row in _sections.get_children():
		if row is HBoxContainer:
			for c in (row as HBoxContainer).get_children():
				if c is Label and c.custom_minimum_size.x > 0.0:
					(c as Label).custom_minimum_size.x = 160.0 if narrow else 240.0
	## Tinggi: header & footer TETAP, bagian tengah digeser bila tidak muat —
	## tinggi panel dibatasi layar (temuan gate: konten 573dp di layar 360dp).
	var need := _sections.get_combined_minimum_size().y
	var max_h: float = minf(PANEL_MAX_H, maxf(0.0, vp.y - 2.0 * MARGIN))
	_scroll.custom_minimum_size = Vector2(maxf(0.0, max_w - pad), 0)
	var chrome := _panel.get_combined_minimum_size().y  ## header+footer+margin
	var room := maxf(0.0, max_h - chrome)
	_scroll.custom_minimum_size = Vector2(maxf(0.0, max_w - pad), minf(need, room))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var panel_need := _panel.get_combined_minimum_size()
	_fit = {"w_need": panel_need.x, "h_need": panel_need.y, "w_max": max_w, "h_max": max_h,
		"sections_need": need, "scroll_h": _scroll.custom_minimum_size.y,
		"chrome": chrome, "padding": pad,
		## toleransi 1,5 px: pembulatan sub-pixel saat HUD di-scale tidak boleh
		## dilaporkan sebagai "melimpah" (temuan gate: 0,6 px → fit=MELIMPAH).
		"fit": panel_need.x <= max_w + 1.5 and panel_need.y <= max_h + 1.5,
		"narrow": narrow}
	_on_resized()


func _viewport_size() -> Vector2:
	## Ruang layout panel = ukuran root (anak HUD full-rect, sudah termasuk
	## scale HUD). Sebelum layout jalan nilainya 0 → JANGAN menebak dengan
	## ukuran viewport (device px, beda satuan saat HUD di-scale: temuan foto
	## portrait "fit=MELIMPAH" palsu & lebar tidak konsisten 1047 vs 656).
	if size.x >= 1.0 and size.y >= 1.0:
		return size
	return Vector2.ZERO


func _fit_when_ready() -> void:
	## Tunggu root punya ukuran nyata (maks 8 frame) baru hitung fit.
	for i in 8:
		if _viewport_size() != Vector2.ZERO:
			break
		await get_tree().process_frame
	_apply_fit()


func _on_resized() -> void:
	_report_panel()


func _report_panel() -> void:
	## Laporan diukur SETELAH layout settle (2 frame): rect sebelum itu masih
	## milik state lama (temuan foto portrait: "MELIMPAH" palsu 1047×960).
	for i in 2:
		await get_tree().process_frame
	var vp := _viewport_size()
	if vp == Vector2.ZERO:
		print("QA:SET:PANEL pending (root belum ter-layout)")
		return
	var r := _panel.get_global_rect()
	var dpr := maxf(0.5, DisplayServer.screen_get_scale())
	## design px → device px: pakai SKALA NYATA panel (HUD scale = dpr/2 ×
	## hud_scale), bukan asumsi dpr/2 — temuan: "on_screen=TIDAK" palsu saat
	## pengguna memilih ukuran UI "Besar" (1,15).
	var s := maxf(0.1, _panel.get_global_transform().get_scale().x)
	var screen_dev := vp * s      ## ukuran layar dalam device px
	var on_screen := r.position.x >= -1.0 and r.position.y >= -1.0 \
		and r.position.x + r.size.x <= screen_dev.x + 1.0 \
		and r.position.y + r.size.y <= screen_dev.y + 1.0
	var w_dp := r.size.x / dpr
	var h_dp := r.size.y / dpr
	print("QA:SET:PANEL rect=%dx%d at=%dx%d screen=%dx%d w_dp=%.0f h_dp=%.0f scroll_h=%.0f on_screen=%s" % [
		int(r.size.x), int(r.size.y), int(r.position.x), int(r.position.y),
		int(screen_dev.x), int(screen_dev.y), w_dp, h_dp,
		float(_fit.get("scroll_h", 0.0)), "ya" if on_screen else "TIDAK"])


func _audit_overlap(tag: String) -> void:
	## Anti-tumpuk (kritik #3): kontrol yang saling menimpa = cacat. Diukur
	## setelah container settle (2 frame) — pelajaran M3.7c/M3 #4.
	_audit_settled(tag)


func _audit_settled(tag: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if visible:
		_measure(tag)


func _visible_rect(ctrl: Control) -> Rect2:
	## Rect yang BENAR-BENAR terlihat: dipotong oleh setiap leluhur yang meng-clip
	## (ScrollContainer / clip_contents). Isi yang tergeser keluar viewport tidak
	## dihitung sebagai tumpukan (temuan gate M3 #5: 3 tumpukan palsu).
	var r := ctrl.get_global_rect()
	var a := ctrl.get_parent()
	while a is Control and a != self:
		var ac := a as Control
		if a is ScrollContainer or ac.clip_contents:
			r = r.intersection(ac.get_global_rect())
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		a = ac.get_parent()
	if clip_contents:
		r = r.intersection(get_global_rect())
	return r


func _measure(tag: String) -> void:
	var rects: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
			if c is Control and (c is Label or c is Button or c is HSlider):
				var ctrl := c as Control
				if ctrl.visible and ctrl.size.x > 0.0:
					var vr := _visible_rect(ctrl)
					if vr.size.x <= 2.0 or vr.size.y <= 2.0:
						continue  ## tergeser keluar area terlihat
					rects.append([ctrl, vr])
	var count := 0
	var pairs: Array[String] = []
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i][1]
			var b: Rect2 = rects[j][1]
			var inter := a.intersection(b)
			if inter.size.x > 2.0 and inter.size.y > 2.0:
				## Anak di dalam orang tua sah (mis. label di dalam baris) — yang
				## dihitung: elemen BUKAN kerabat langsung.
				var na: Control = rects[i][0]
				var nb: Control = rects[j][0]
				if na.is_ancestor_of(nb) or nb.is_ancestor_of(na):
					continue
				count += 1
				pairs.append("%s-%s" % [na.name, nb.name])
	print("QA:SET:OVERLAP tag=%s count=%d %s" % [tag, count, " ".join(pairs)])
