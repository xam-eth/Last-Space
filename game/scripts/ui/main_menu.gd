extends Control
## MainMenu — layar menu utama (GAMEPLAY_FLOW.md §3 Frame 3, M3 #4).
##
## Tata letak ditiru dari referensi NYATA (docs/REFERENCES_MAIN_MENU.md — riset,
## bukan asumsi):
##   - Doomsday: Last Survivors Frame 1 (login/menu): latar = scene 3D nyata
##     (base hidup) + tombol Start BESAR di tengah-bawah; ikon kecil di atas.
##   - Clash of Clans (blog revamp resmi Supercell): "everything on screen that
##     isn't the village itself is UI" → base 3D tetap terlihat, menu = lapisan
##     chrome, bukan layar penuh yang menutup game.
##   - therookies.co (prinsip satu tangan): aksi utama di area bawah (jempol),
##     bukan di atas.
##   - Material 3 + UI_UX_DESIGN.md §3: tombol utama 56dp, sekunder ≥48dp,
##     panel ≤560dp, margin 16dp, teks ≥11dp (design px = dp × 2).
##
## Root game TETAP game (requirement human): index.html → loading → game, dan
## game boot ke fase MENU dengan base 3D idle di belakang. Tombol Play →
## fase COMMAND (HUD chrome muncul). Menu TIDAK menggantikan scene game.
##
## Ukuran panel (design px) dihitung dari konten NYATA (get_combined_minimum_size
## → bukan angka tebakan); lebar dasar 672 = 336dp (area tombol 320dp + margin
## 16dp), anchor TENGAH-BAWAH (pola tombol Start Doomsday).

const PANEL_W := 672    ## 336dp (320dp isi + 2×8dp margin dalam)
const MIN_H := 320      ## 160dp — tinggi minimum bila konten sedikit

## Aksi pemain (string ini juga dipakai di marker QA & nilai balik test).
const ACT_NEW := "new"
const ACT_LOAD := "load"
const ACT_RESUME := "resume"

signal play_requested(action: String)  ## HUD: tampilkan chrome + lanjutkan waktu

var _scrim: ColorRect
var _panel: PanelContainer
var _body: VBoxContainer
var _info: Label
var _primary: Button
var _settings_btn: Button
var _extra_row: HBoxContainer
var _new_btn: Button
var _credits_btn: Button
var _status: Label
var _credits_scrim: ColorRect  ## scrim khusus modal (klik luar tidak menembus)
var _credits: PanelContainer
var _credits_body: VBoxContainer
var _settings_panel: SettingsPanel = null  ## panel PENGATURAN (M3 #5)
var _session_active := false  ## true setelah game dimulai pada boot ini
var _fit: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  ## saat hidden tidak blok arena
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Design frame: di produksi menu dipasang di dalam HUDControl (parent Control
	# sudah punya scale = dpr/2 → diwarisi); saat dipasang langsung ke root
	# (test/e2e), menu menerapkan frame sendiri — ukuran tetap dalam dp.
	if not (get_parent() is Control):
		UiTheme.apply_design_frame(self)
		get_viewport().size_changed.connect(_on_viewport_resized)

	# Scrim tipis: base 3D tetap terbaca (pola "base hidup" Doomsday/CoC),
	# tidak menutup penuh seperti dim modal.
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = UiTheme.C_SCRIM
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	# --- panel tengah-bawah (aksi utama di zona jempol) ---
	_panel = PanelContainer.new()
	_panel.name = "MenuPanel"
	_panel.custom_minimum_size = Vector2(PANEL_W, MIN_H)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -PANEL_W / 2.0
	_panel.offset_right = PANEL_W / 2.0
	_panel.offset_top = -(MIN_H + UiTheme.MARGIN)
	_panel.offset_bottom = -UiTheme.MARGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_box())
	add_child(_panel)

	_body = VBoxContainer.new()
	_body.name = "MenuBody"
	_body.add_theme_constant_override("separation", UiTheme.GAP)
	_panel.add_child(_body)

	var head := HBoxContainer.new()
	head.name = "HeadRow"
	head.add_theme_constant_override("separation", UiTheme.GAP)
	_body.add_child(head)
	var title := Label.new()
	title.name = "Title"
	title.label_settings = UiTheme.ls(48, UiTheme.C_TEXT)  ## 24dp
	title.text = "LAST-SPACE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var ver := Label.new()
	ver.name = "Version"
	ver.label_settings = UiTheme.ls(22, UiTheme.C_MUTED)  ## 11dp
	ver.text = "M3 #4"
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(ver)

	_info = Label.new()
	_info.name = "SaveInfo"
	_info.label_settings = UiTheme.ls(22, UiTheme.C_ACCENT)  ## 11dp
	_body.add_child(_info)

	_primary = Button.new()
	_primary.name = "PrimaryButton"
	UiTheme.style_button(_primary, true)
	_primary.pressed.connect(press_primary)
	_body.add_child(_primary)

	_settings_btn = Button.new()
	_settings_btn.name = "SettingsButton"
	_settings_btn.text = "PENGATURAN"
	UiTheme.style_button(_settings_btn)
	_settings_btn.pressed.connect(press_settings)
	_body.add_child(_settings_btn)

	_extra_row = HBoxContainer.new()
	_extra_row.name = "ExtraRow"
	_extra_row.add_theme_constant_override("separation", UiTheme.GAP)
	_body.add_child(_extra_row)
	_new_btn = _make_extra("MULAI BARU")
	_new_btn.name = "NewGameButton"
	_new_btn.pressed.connect(func(): _start(ACT_NEW))
	_credits_btn = _make_extra("KREDIT")
	_credits_btn.name = "CreditsButton"
	_credits_btn.pressed.connect(press_credits)

	_status = Label.new()
	_status.name = "Status"
	_status.label_settings = UiTheme.ls(22, UiTheme.C_MUTED)  ## 11dp
	_body.add_child(_status)

	# --- modal kredit (dialog Material: ≤560dp, tombol TUTUP 48dp) ---
	_credits_scrim = ColorRect.new()
	_credits_scrim.name = "CreditsScrim"
	_credits_scrim.color = UiTheme.C_SCRIM
	_credits_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits_scrim.visible = false
	## Standar dialog Material: tap di luar dialog menutupnya (di mobile tidak
	## ada tombol Esc) — scrim menangkap tap, bukan arena di belakangnya.
	_credits_scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			press_credits_close())
	add_child(_credits_scrim)   ## z-order: di atas panel, di bawah modal

	_credits = PanelContainer.new()
	_credits.name = "CreditsPanel"
	_credits.custom_minimum_size = Vector2(640, 400)
	_credits.set_anchors_preset(Control.PRESET_CENTER)
	_credits.offset_left = -320
	_credits.offset_right = 320
	_credits.offset_top = -200
	_credits.offset_bottom = 200
	_credits.mouse_filter = Control.MOUSE_FILTER_STOP
	## Modal = permukaan opaque + border terang (Material dialog: scrim +
	## surface terpisah dari panel di belakangnya).
	_credits.add_theme_stylebox_override("panel",
		UiTheme.panel_box(UiTheme.C_MODAL, UiTheme.C_BORDER_SEL))
	_credits.visible = false
	add_child(_credits)
	_credits_body = VBoxContainer.new()
	_credits_body.name = "CreditsBody"
	_credits_body.add_theme_constant_override("separation", UiTheme.GAP)
	_credits.add_child(_credits_body)
	var ct := Label.new()
	ct.label_settings = UiTheme.ls(32, UiTheme.C_TEXT)  ## 16dp
	ct.text = "KREDIT"
	_credits_body.add_child(ct)
	var cb := Label.new()
	cb.name = "CreditsText"
	cb.label_settings = UiTheme.ls(22, UiTheme.C_MUTED)  ## 11dp
	## Baris eksplisit (bukan autowrap): min-size Label autowrap = per-kata →
	## tinggi palsu 6222px (temuan run gate: credits_fit=MELIMPAH). Dengan baris
	## pendek eksplisit, ukuran panel kredit benar-benar terukur.
	cb.text = "Godot Engine 4.7 (MIT) — build Web/WASM.\nModel 3D & ikon: digambar prosedural dari kode.\nScreenshot game lain: referensi internal repo."
	_credits_body.add_child(cb)
	var close := Button.new()
	close.name = "CreditsClose"
	close.text = "TUTUP"
	UiTheme.style_button(close)
	close.pressed.connect(press_credits_close)
	_credits_body.add_child(close)

	refresh()
	_sync_layout()


func _on_viewport_resized() -> void:
	if not (get_parent() is Control):
		UiTheme.apply_design_frame(self)
	_sync_layout()


func _make_extra(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(b)
	_extra_row.add_child(b)
	return b


# ------------------------------------------------------------ public API ---
func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  ## blok klik ke arena saat menu
	_status.text = ""
	_set_credits_visible(false)
	refresh()
	_sync_layout()
	QaMarkers.marker("MENU", "READY", {
		"panel": "%dx%d" % [int(_panel.size.x), int(_panel.size.y)],
		"primary": _primary.text, "has_save": SaveSystem.has_save(),
		"session": _session_active, "phase": GameManager.get_phase_name(),
	})
	QaMarkers.marker("MENU", "FIT", _fit)
	_audit_overlap_later("panel")  ## layout container settle dulu (2 frame)
	QaMarkers.marker("MENU", "DUMP", {
		"primary_h": int(_primary.size.y), "secondary_h": int(_settings_btn.size.y),
		"primary_dp": int(_primary.custom_minimum_size.y / 2.0),
		"secondary_dp": int(_settings_btn.custom_minimum_size.y / 2.0),
	})


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_credits_visible(false)
	QaMarkers.marker("MENU", "CLOSE", {})


func is_open() -> bool:
	return visible


## Penanda sesi: setelah pemain menekan Play pada boot ini, "Lanjutkan" =
## resume sesi berjalan (tanpa reset/load) supaya tidak ada state campur.
func set_session_active(active: bool) -> void:
	_session_active = active
	refresh()


func is_session_active() -> bool:
	return _session_active


## Label tombol + baris tombol dibangun dari STATE NYATA (save ada/tidak,
## sesi berjalan/tidak) — bukan teks tetap.
func refresh() -> void:
	var has := SaveSystem.has_save()
	if _session_active:
		_primary.text = "LANJUTKAN PERMAINAN"
		_info.text = "Sesi berjalan"
	elif has:
		_primary.text = "LANJUTKAN"
		_info.text = _save_summary()
	else:
		_primary.text = "MULAI"
		_info.text = "Belum ada simpanan — mulai permainan baru"
	_new_btn.visible = not _session_active and has
	_sync_layout()


## Tombol utama: aksi ditentukan state nyata (sesi → resume, save → load,
## selain itu → game baru). Mengembalikan aksi yang dijalankan (untuk test).
func press_primary() -> String:
	var act := ACT_NEW
	if _session_active:
		act = ACT_RESUME
	elif SaveSystem.has_save():
		act = ACT_LOAD
	_start(act)
	return act


func press_settings() -> void:
	## M3 #5: pengaturan SUDAH ada (audio/tampilan/ukuran UI/bahasa) → panel
	## MILIK HUD (full layar) supaya dialog tidak terpotong rect panel menu.
	var hud := get_parent()
	if hud != null and hud.has_method("open_settings"):
		_settings_panel = hud.call("get_settings_panel")
		hud.call("open_settings")
	else:
		_fallback_settings()
	AudioSystem.ui_click()
	QaMarkers.marker("MENU", "ACTION", {"action": "settings", "available": true})


func _fallback_settings() -> void:
	## Dipakai bila MainMenu dipakai lepas dari HUD (test unit/dokumentasi).
	if _settings_panel == null:
		_settings_panel = SettingsPanel.new()
		add_child(_settings_panel)
	_settings_panel.open()


func get_settings_panel() -> SettingsPanel:
	var hud := get_parent()
	if hud != null and hud.has_method("get_settings_panel"):
		return hud.call("get_settings_panel")
	return _settings_panel


func close_settings() -> void:
	if _settings_panel != null:
		_settings_panel.close()


func _set_credits_visible(v: bool) -> void:
	## Modal + scrim selalu sepasang (scrim mencegah klik tembus ke panel/arena).
	_credits.visible = v
	if _credits_scrim != null:
		_credits_scrim.visible = v
	## Bukti terukur: permukaan modal opaque (elemen panel di belakangnya tidak
	## boleh terbaca menembus) + scrim aktif. Temuan foto KREDIT (teks panel
	## samar terlihat di atas modal = kesan teks bertumpuk).
	QaMarkers.marker("MENU", "MODAL", {
		"visible": v, "scrim": _credits_scrim != null and _credits_scrim.visible,
		"surface_alpha": UiTheme.C_MODAL.a,
	})


func press_credits() -> void:
	_set_credits_visible(true)
	_audit_overlap_later("credits_open")
	QaMarkers.marker("MENU", "ACTION", {"action": "credits", "visible": true})


func press_credits_close() -> void:
	_set_credits_visible(false)
	QaMarkers.marker("MENU", "ACTION", {"action": "credits", "visible": false})


func get_credits_panel() -> Control:
	return _credits


func get_primary_button() -> Button:
	return _primary


func get_settings_button() -> Button:
	return _settings_btn


func fit_report() -> Dictionary:
	return _fit


## Verifikasi anti-tumpuk OTOMATIS dari rect NYATA (kriteria user #3: teks/ikon
## tidak boleh bertumpuk) — pola sama dengan QA:HUD:OVERLAP di HUD: traversal
## penuh subtree panel, pasangan overlap dihitung, target 0.
func _audit_overlap_later(tag: String) -> void:
	## Rect nyata baru valid setelah container men-sort anaknya (2 frame —
	## pelajaran sama dengan ui_showcase/_modal_overflow: mengukur sebelum
	## settle = hasil palsu).
	await get_tree().process_frame
	await get_tree().process_frame
	_audit_overlap(tag)


func _audit_overlap(tag: String) -> void:
	var zones: Array[Control] = []
	## Saat modal terbuka, audit HANYA isi modal: modal memang menutupi panel
	## (overlap panel↔modal = by design, bukan cacat tata letak).
	var stack: Array = [_credits] if (_credits.visible and tag == "credits_open") else [_panel]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			if not (c is Control):
				continue
			stack.append(c)
			## Hanya LEAF (label/tombol tanpa anak Control): container sengaja
			## memuat anaknya, jadi pasangan parent-child BUKAN overlap.
			var leaf := true
			for g in c.get_children():
				if g is Control:
					leaf = false
					break
			if leaf:
				zones.append(c)
	var pairs: Array[String] = []
	for i in range(zones.size()):
		for j in range(i + 1, zones.size()):
			var a := zones[i]
			var b := zones[j]
			if not a.visible or not b.visible:
				continue
			var inter := a.get_global_rect().intersection(b.get_global_rect())
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				pairs.append("%s-%s:%.0fx%.0f" % [a.name, b.name, inter.size.x, inter.size.y])
	QaMarkers.marker("MENU", "OVERLAP", {"scope": tag, "zones": zones.size(),
		"count": pairs.size(), "pairs": str(pairs)})


# -------------------------------------------------------------- internal ---
func _start(act: String) -> void:
	match act:
		ACT_NEW:
			GameManager.start_new_game()  ## reset ekonomi + fase COMMAND
		ACT_LOAD:
			if not SaveSystem.load_game():
				_status.text = "Simpanan gagal dimuat — mulai permainan baru"
				_status.label_settings.font_color = UiTheme.C_DANGER
				GameManager.start_new_game()
				act = ACT_NEW
			else:
				## Save bisa saja dibuat saat fase PAUSE/MENU (save saat jeda /
				## dari menu). Menekan LANJUTKAN = MASUK GAMEPLAY → fase wajib
				## COMMAND (temuan gate menu: fase tersimpan MENU ikut ter-restore
				## → pemain berhenti di menu setelah "LANJUTKAN").
				GameManager.enter_gameplay()
		ACT_RESUME:
			GameManager.enter_gameplay()
	_session_active = true
	close()
	QaMarkers.marker("MENU", "PLAY", {"action": act, "phase": GameManager.get_phase_name(),
		"ticks": TimeSystem.tick_count})
	play_requested.emit(act)


## Tinggi/lebar panel = konten NYATA (min-size hasil layout) → tidak ada
## konten terpotong dan tidak ada ruang kosong (verifikasi QA:MENU:FIT).
func _sync_layout() -> void:
	var need := _body.get_combined_minimum_size()
	## Lebar: 336dp standar; menyusut bila layar lebih sempit (portrait 360dp)
	## sampai sisa margin samping minimum 8dp — bukan meluber keluar layar.
	var side_min := 16.0  ## 8dp
	var max_w := maxf(320.0, size.x - 2.0 * side_min)
	var w := clampf(maxf(PANEL_W, need.x + UiTheme.MARGIN * 2.0), 320.0, max_w)
	var h := maxf(MIN_H, need.y + UiTheme.MARGIN * 2.0)
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.offset_left = -w / 2.0
	_panel.offset_right = w / 2.0
	_panel.offset_top = -(h + UiTheme.MARGIN)   ## 16dp dari tepi bawah
	_panel.offset_bottom = -UiTheme.MARGIN
	var avail := size  ## design space (1280×720 pada baseline 360dp)
	## Modal kredit: ukuran = konten nyata, dibatasi anggaran dialog Material
	## (≤560dp = 1120px lebar) dan tinggi layar design.
	var cneed := _credits_body.get_combined_minimum_size()
	var cw := maxf(560.0, cneed.x + UiTheme.MARGIN * 2.0)
	var ch := maxf(320.0, cneed.y + UiTheme.MARGIN * 2.0)
	_credits.custom_minimum_size = Vector2(cw, ch)
	_credits.offset_left = -cw / 2.0
	_credits.offset_right = cw / 2.0
	_credits.offset_top = -ch / 2.0
	_credits.offset_bottom = ch / 2.0
	_fit = {
		"content": "%dx%d" % [int(need.x), int(need.y)],
		"panel": "%dx%d" % [int(w), int(h)],
		"avail": "%dx%d" % [int(avail.x), int(avail.y)],
		"credits": "%dx%d" % [int(cw), int(ch)],
		"credits_fit": "ok" if (cw <= 1120.0 and ch + 2.0 * UiTheme.MARGIN <= avail.y) else "MELIMPAH",
		"side_dp": int(((avail.x - w) / 2.0) / 2.0),
		"off_dp": int(UiTheme.MARGIN / 2.0),  ## jarak panel ke tepi bawah (dp)
		"fit": "ok" if (w <= avail.x and h + 2.0 * UiTheme.MARGIN <= avail.y) else "MELIMPAH",
		"primary_dp": int(_primary.custom_minimum_size.y / 2.0),
		"secondary_dp": int(_settings_btn.custom_minimum_size.y / 2.0),
	}


## Ringkasan simpanan dibaca dari FILE SAVE (bukan tebakan): wave + waktu main.
func _save_summary() -> String:
	var path := "user://default.json"
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = parsed
	var secs := int(round(int(d.get("game_time_ticks", 0)) / float(TimeSystem.TICKS_PER_SECOND)))
	var wd: Variant = d.get("wave_director", {})
	var wave := 0
	if typeof(wd) == TYPE_DICTIONARY:
		var w: Dictionary = wd
		if w.has("current_wave"):
			wave = int(w["current_wave"])
		elif w.has("wave_index"):
			wave = int(w["wave_index"])
	return "Simpanan: wave %d · waktu main %d:%02d" % [wave, secs / 60, secs % 60]
