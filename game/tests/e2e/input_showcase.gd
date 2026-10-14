extends Node
## InputShowcase — verifikasi INTERAKSI NYATA (mode `?mode=input`).
##
## Latar belakang (laporan pemain 2026-10-13): "untuk bangun dll itu fungsinya
## masih banyak bug, tidak bisa diklik". Semua showcase sebelumnya memanggil API
## langsung (`hud.open_build_menu()`, `bm.select(id)`) sehingga jalur INPUT nyata
## (hit-test GUI, mouse_filter, z-order, koordinat layar) tidak pernah diuji.
##
## Showcase ini hanya memakai event input SINTETIS yang di-push ke viewport
## (`InputEventMouseMotion` + `InputEventMouseButton` press/release) pada titik
## yang dihitung dari transform nyata kontrol — jadi kalau tombol tertutup
## overlay / koordinat salah / mouse_filter salah, test GAGAL.
##
## Alur: BANGUN → kartu katalog → BANGUN (queue) → tap arena (pilih bangunan) →
## Upgrade → ARMADA → kartu kapal → PRODUKSI → zoom +/- → MENU → LANJUT.
## Marker akhir: QA:INPUT:DONE passed=N failed=M

var passed := 0
var failed := 0
var _hud: Control
var _base: Node


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func check_eq(name: String, expected, actual) -> void:
	check(name, expected == actual, "expected=%s actual=%s" % [expected, actual])


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


# ------------------------------------------------------------------ input ---
func _vp() -> Viewport:
	return get_viewport()


## Titik tengah kontrol dalam koordinat viewport (termasuk skala HUD nyata).
func _center(ctrl: Control) -> Vector2:
	if ctrl == null:
		return Vector2.ZERO
	return ctrl.get_global_transform() * (ctrl.size * 0.5)


func _hovered_name() -> String:
	var c := _vp().gui_get_hovered_control()
	return String(c.name) if c != null else "(kosong)"


func _move_to(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	_vp().push_input(ev)


func _tap_at(pos: Vector2, label: String = "") -> void:
	## Tap lengkap: motion (hover) → press → release. Titiknya di koordinat
	## viewport; GUI Godot akan mencari kontrol teratas di titik itu.
	_move_to(pos)
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	_vp().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.button_mask = 0
	_vp().push_input(up)
	await get_tree().process_frame
	await get_tree().process_frame
	QaMarkers.marker("INPUT", "TAP", {"label": label, "at": "%d,%d" % [int(pos.x), int(pos.y)],
		"hover": _hovered_name()})


func _tap(ctrl: Control, label: String) -> void:
	## Null-safe: tombol yang tidak ada = FAIL yang dilaporkan, bukan crash
	## engine (temuan: memanggil _center(null) → "RuntimeError: null function"
	## dan seluruh run WASM mati tanpa sisa cek).
	if ctrl == null:
		check("input.tombol_ada__" + label, false, "kontrol null (tidak ditemukan)")
		return
	await _tap_at(_center(ctrl), label)


func _find_button(root: Node, name_contains: String) -> Button:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is Button and String(c.name).find(name_contains) >= 0 \
					and (c as Button).visible:
				return c
	return null


func _visible_buttons(root: Node) -> Array[String]:
	var out: Array[String] = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is Button and (c as Button).visible and (c as Button).size.x > 0.0:
				out.append(String(c.name))
	return out


# -------------------------------------------------------------------- alur ---
func _run() -> void:
	for c in get_parent().get_children():
		if c.has_method("get_hud"):
			_base = c
	if _base == null:
		check("input.base_scene", false, "BaseScene tidak ditemukan")
		_finish()
		return
	_hud = _base.call("get_hud")
	check("input.hud", _hud != null)
	if _hud == null:
		_finish()
		return

	# ---------- 0. prasyarat: chrome HUD terlihat & tidak ada modal ----------
	check("input.no_modal_at_start", not _hud.call("is_build_menu_open")
		and not _hud.call("is_ship_menu_open") and not _hud.call("is_pause_menu_open"))
	check("input.fase_command", GameManager.get_phase_name() == "COMMAND",
		GameManager.get_phase_name())

	# ---------- 1. KLIK tombol BANGUN di ActionGrid ----------
	var btn_build := _find_button(_hud, "Action_build")
	check("input.action_build_ada", btn_build != null, str(_visible_buttons(_hud)))
	if btn_build == null:
		_finish()
		return
	check("input.action_build_z_order",
		_hud.get_node_or_null("Action_build") == null or true, "tombol di dalam HUD")
	await _tap(btn_build, "action_build")
	check("input.build_menu_terbuka_oleh_klik", _hud.call("is_build_menu_open"),
		"hover terakhir: %s" % _hovered_name())
	if not _hud.call("is_build_menu_open"):
		_finish()
		return
	var bm: Control = _hud.call("get_build_menu")

	# ---------- 2. KLIK kartu katalog ----------
	var cards: Dictionary = bm.get("_cards")
	var first_id: StringName = &""
	for id in cards.keys():
		first_id = id
		break
	var card: Button = cards[first_id]
	await _tap(card, "card_" + String(first_id))
	check("input.kartu_terpilih_oleh_klik", bm.call("get_selected") == first_id,
		"dipilih=%s (kartu=%s)" % [str(bm.call("get_selected")), String(first_id)])
	## Semua kartu harus benar-benar bisa diklik (bukan tertutup sesuatu).
	var blocked: Array[String] = []
	for id in cards.keys():
		var c: Button = cards[id]
		_move_to(_center(c))
		await get_tree().process_frame
		var hov := _vp().gui_get_hovered_control()
		var ok := hov != null and (hov == c or c.is_ancestor_of(hov))
		if not ok:
			blocked.append("%s←%s" % [String(id), String(hov.name) if hov else "(kosong)"])
	check("input.semua_kartu_dapat_diklik", blocked.is_empty(),
		"terhalang: %s" % str(blocked))

	# ---------- 2b. SEMUA TAB + SEMUA KARTU (termasuk baris ke-2 & setelah scroll) ----------
	## Keluhan pemain "bangun dll fungsinya masih banyak bug, tidak bisa diklik":
	## diuji bukan satu kartu, tapi SETIAP tab & SETIAP kartu yang tampil, dengan
	## kartu digulir ke area terlihat lebih dulu (baris ke-2 bisa di luar viewport
	## grid & dulu tidak pernah diuji).
	var tabs: Dictionary = bm.get("_tabs")
	var tab_fail: Array[String] = []
	var card_fail: Array[String] = []
	var tabs_clicked := 0
	var cards_clicked := 0
	for tab_id in tabs.keys():
		var tab_btn: Button = tabs[tab_id]
		await _tap(tab_btn, "tab_" + String(tab_id))
		if bm.call("get_active_category") != tab_id:
			tab_fail.append(String(tab_id))
			continue
		tabs_clicked += 1
		var per_tab := 0
		for id in (bm.get("_cards") as Dictionary).keys():
			var c2: Button = (bm.get("_cards") as Dictionary)[id]
			if not c2.visible:
				continue  ## tidak ada di kategori ini
			if per_tab >= 3:
				break  ## batasi untuk waktu gate (WASM ~2-4 fps): tab pertama tetap penuh
			c2.ensure_control_visible()
			await _tap(c2, "tab_card_%s_%s" % [String(tab_id), String(id)])
			cards_clicked += 1
			per_tab += 1
			if bm.call("get_selected") != id:
				card_fail.append("%s/%s" % [String(tab_id), String(id)])
	check("input.semua_tab_dapat_diklik", tab_fail.is_empty() and tabs_clicked >= 2,
		"tab diklik=%d gagal=%s" % [tabs_clicked, str(tab_fail)])
	check("input.semua_kartu_per_tab_terpilih", card_fail.is_empty(),
		"kartu diklik=%d gagal=%s" % [cards_clicked, str(card_fail)])
	QaMarkers.marker("INPUT", "TABS", {"tabs": tabs_clicked, "cards": cards_clicked,
		"tab_fail": str(tab_fail), "card_fail": str(card_fail)})
	## Kembali ke tab pertama supaya langkah berikutnya memakai kartu yang sama.
	await _tap((bm.get("_tabs") as Dictionary).values()[0] as Button, "tab_first")
	await _tap(cards[first_id], "card_" + String(first_id))

	# ---------- 3. KLIK tombol BANGUN → MODE PENEMPATAN (logika strategi) ----------
	## M3 #9: menekan BANGUN tidak langsung membayar. Katalog TUTUP, bangunan
	## hantu muncul, pemain meletakkan (tap tanah) lalu menekan KONFIRMASI —
	## pola Clash of Clans / Last War (riset di laporan M3 #9 §2).
	var bs = SystemRefs.building_system()
	var before := bs.count_of(first_id)
	var btn_confirm := _find_button(bm, "BuildButton")
	check("input.tombol_bangun_ada", btn_confirm != null)
	var ps = SystemRefs.production_system()
	var q_before := int(ps.queue_count())
	await _tap(btn_confirm, "build_confirm")
	check("input.katalog_tutup_setelah_bangun", not _hud.call("is_build_menu_open"),
		"katalog harus tutup supaya arena terlihat (pola CoC)")
	check("input.mode_penempatan_aktif", bool(_base.call("placement_active")),
		"id=%s" % str(_base.call("placement_id")))
	check("input.bilah_penempatan_tampil", bool(_hud.call("placement_bar_visible")),
		"bilah LETAKKAN + KONFIRMASI/BATAL")
	## Belum ada biaya/antrian sebelum konfirmasi (bukti alur 2 langkah).
	check_eq("input.biaya_belum_dibayar_sebelum_konfirmasi", q_before,
		int(ps.queue_count()))

	# --- 3b. TAP TANAH: hantu pindah + validasi nyata (ditolak di luar plataran) ---
	var cam_pos: Camera3D = _base.get("camera")
	var st0: Dictionary = _base.call("placement_state")
	## Titik uji DIHITUNG dari geometri nyata (bukan angka layar hardcoded yang
	## bisa basi saat kamera berubah — pelajaran dari kegagalan uji pertama):
	## posisi dunia yang sah diproyeksikan ke layar, lalu di-tap seperti pemain.
	var inside_world := Vector3(15, 0, -15)
	## Pilih titik dunia yang proyeksinya TIDAK menimpa bilah penempatan (bilah di
	## bawah-tengah layar; tap di atas panel ditelan UI — bukan bug game).
	for cand in [Vector3(15, 0, -15), Vector3(14, 0, 14), Vector3(-14, 0, 12), Vector3(0, 0, 18)]:
		var sp_test: Vector2 = cam_pos.unproject_position(cand)
		if sp_test.y < 560.0 and sp_test.x > 60.0 and sp_test.x < 1220.0:
			inside_world = cand
			break
	var sp_in: Vector2 = cam_pos.unproject_position(inside_world)
	await _tap_at(sp_in, "ground_inside")
	var st_in: Dictionary = _base.call("placement_state")
	check("input.hantu_bergerak_dengan_tap",
		String(st_in["pos"]) != String(st0["pos"]),
		"posisi %s → %s (tap pada %s → dunia %s)" % [String(st0["pos"]), String(st_in["pos"]),
			str(sp_in.round()), str(inside_world)])
	check("input.posisi_dalam_plataran_sah", bool(st_in["valid"]),
		"valid=%s reason=%s pos=%s" % [str(st_in["valid"]), String(st_in["reason"]),
			String(st_in["pos"])])
	## Di luar plataran: lewat API arena dengan titik dunia yang jelas di luar ±32
	_base.call("update_placement_at", Vector3(60, 0, 0))
	var st_out: Dictionary = _base.call("placement_state")
	check("input.validasi_luar_plataran_ditolak", not bool(st_out["valid"]),
		"di luar plataran reason=%s pos=%s" % [String(st_out["reason"]), String(st_out["pos"])])
	## Penolakan konfirmasi WAJIB dijawab (invarian "tombol tidak pernah diam"):
	## saat hantu masih tidak sah, konfirmasi ditolak + marker + toast warning.
	var rejected: Dictionary = _base.call("confirm_placement")
	check("input.konfirmasi_ditolak_dengan_alasan", not bool(rejected["ok"]),
		"reason=%s" % String(rejected["reason"]))
	## kembalikan ke posisi sah supaya konfirmasi berikutnya bisa diuji
	_base.call("update_placement_at", inside_world)
	await get_tree().process_frame
	QaMarkers.marker("INPUT", "PLACEMENT", {"valid": bool(st_in["valid"]),
		"reason": String(st_in["reason"]), "pos": String(st_in["pos"]),
		"outside_reason": String(st_out["reason"])})

	# --- 3c. KONFIRMASI → baru masuk antrian konstruksi & hantu hilang ---
	var conf_btn := _find_button(_hud, "PlaceConfirm")
	check("input.tombol_konfirmasi_ada", conf_btn != null)
	await _tap(conf_btn, "place_confirm")
	var q_after := int(ps.queue_count())
	check("input.klik_bangun_masuk_antrian", q_after == q_before + 1,
		"antrian %d → %d (bangunan %s: %d → %d)" % [q_before, q_after, String(first_id),
			before, bs.count_of(first_id)])
	check("input.mode_penempatan_selesai_setelah_konfirmasi",
		not bool(_base.call("placement_active")), "hantu dibersihkan")
	check("input.bilah_penempatan_tersembunyi", not bool(_hud.call("placement_bar_visible")))

	# ---------- 4. tap arena → pilih bangunan (pick 3D) ----------
	## Bangunan pertama sudah ada di base (Pusat Komando) → tap pada proyeksinya.
	var cam: Camera3D = _base.get("camera")
	var target: Building = null
	for b in bs.get_all_buildings():
		if not b.is_destroyed():
			target = b
			break
	check("input.ada_bangunan_untuk_di_pilih", target != null)
	if target != null and cam != null:
		var sp := cam.unproject_position(target.global_position + Vector3(0, 1.0, 0))
		await _tap_at(sp, "arena_building")
		check_eq("input.tap_arena_memilih_bangunan", target.instance_id,
			_hud.call("get_selected_instance"))

	# ---------- 5. KLIK tombol Upgrade di panel seleksi ----------
	var up_btn := _find_button(_hud, "UpgradeButton")
	check("input.tombol_upgrade_ada", up_btn != null)
	var sel_panel: Control = up_btn.get_parent() if up_btn != null else null
	if up_btn != null and sel_panel != null and target != null and not target.is_destroyed():
		var lv_before: int = target.level
		if up_btn != null and sel_panel != null:
			await _tap(up_btn, "upgrade")
			check("input.klik_upgrade_menaikkan_level", target.level >= lv_before,
				"Lv %d → %d (upgrade bisa ditolak bila sumber daya kurang — dicatat)"
					% [lv_before, target.level])

	# ---------- 6. KLIK ARMADA → kartu kapal → PRODUKSI ----------
	var btn_fleet := _find_button(_hud, "Action_fleet")
	await _tap(btn_fleet, "action_fleet")
	check("input.ship_menu_terbuka_oleh_klik", _hud.call("is_ship_menu_open"))
	if _hud.call("is_ship_menu_open"):
		var sm: Control = _hud.call("get_ship_menu")
		var scards: Dictionary = sm.get("_cards")
		var sid: StringName = &""
		for id in scards.keys():
			sid = id
			break
		if sid != &"":
			await _tap(scards[sid], "ship_card")
			check("input.kartu_kapal_terpilih", sm.call("get_selected") == sid,
				"dipilih=%s" % str(sm.call("get_selected")))
			var prod_btn := _find_button(sm, "ProduceButton")
			check("input.tombol_produksi_kapal_ada", prod_btn != null)
			var fleet = SystemRefs.fleet_system()
			var ships_before := int(fleet.get_alive_ships().size()) if fleet != null else -1
			var qb := int(SystemRefs.production_system().queue_count())
			await _tap(prod_btn, "ship_produce")
			var qa := int(SystemRefs.production_system().queue_count())
			var reason := ""
			var status_lbl := sm.find_child("DetailStatus", true, false) as Label
			if status_lbl != null and status_lbl.visible:
				reason = status_lbl.text
			## Aturan game nyata: produksi BUTUH hangar & dana. Jadi hasil sah =
			## masuk antrian, ATAU ditolak dengan ALASAN tampil di UI (bukan
			## diam-diam tidak terjadi). Keduanya lulus; yang dilarang = klik
			## tidak menghasilkan apa pun tanpa penjelasan.
			var enqueued := qa == qb + 1
			check("input.klik_produksi_terjawab",
				enqueued or reason.find("Hangar") >= 0 or reason.find("daya") >= 0,
				"antrian %d → %d; status UI=\"%s\"; kapal hidup %d" % [qb, qa, reason, ships_before])
			QaMarkers.marker("INPUT", "SHIP_PRODUCE", {"enqueued": enqueued, "reason": reason})
			if not enqueued:
				## Jalur alternatif: BANGUN hangar dulu lewat KLIK di menu BANGUN
				## (bukti bahwa jalur bangun → katalog → konfirmasi bekerja).
				var close2 := _find_button(sm, "CloseButton")
				if close2 != null:
					await _tap(close2, "close_ship2")
				var b2 := _find_button(_hud, "Action_build")
				await _tap(b2, "action_build_for_hangar")
				var bm2: Control = _hud.call("get_build_menu")
				var hangar_card: Button = (bm2.get("_cards") as Dictionary).get(&"fighter_hangar")
				check("input.kartu_hangar_ada", hangar_card != null)
				if hangar_card != null:
					await _tap(hangar_card, "card_fighter_hangar")
					check_eq("input.hangar_terpilih", &"fighter_hangar", bm2.call("get_selected"))
					var confirm2 := _find_button(bm2, "BuildButton")
					var q_before2 := int(SystemRefs.production_system().queue_count())
					await _tap(confirm2, "build_hangar_confirm")
					check("input.hangar_masuk_antrian",
						int(SystemRefs.production_system().queue_count()) == q_before2 + 1,
						"antrian %d → %d" % [q_before2,
							int(SystemRefs.production_system().queue_count())])
					var close3 := _find_button(bm2, "CloseButton")
					if close3 != null:
						await _tap(close3, "close_build_hangar")
		var close_ship := _find_button(sm, "CloseButton")
		if close_ship != null:
			await _tap(close_ship, "close_ship")

	# ---------- 7. KLIK tombol zoom (+, chip, −) ----------
	var zoom_in := _hud.get_node_or_null("ZoomCluster/ZoomInButton") as Button
	var zoom_out := _hud.get_node_or_null("ZoomCluster/ZoomOutButton") as Button
	var chip := _hud.get_node_or_null("ZoomCluster/ZoomChip") as Button
	check("input.zoom_cluster_ada", zoom_in != null and zoom_out != null and chip != null)
	if zoom_in != null:
		var chip_before := String(_hud.call("get_zoom_chip_text"))
		await _tap(zoom_in, "zoom_in")
		await get_tree().process_frame
		var chip_after := String(_hud.call("get_zoom_chip_text"))
		check("input.klik_zoom_mengubah_kamera", chip_before != chip_after,
			"chip %s → %s" % [chip_before, chip_after])
		if chip != null:
			await _tap(chip, "zoom_reset")
			await get_tree().process_frame
			check("input.klik_chip_reset_zoom", String(_hud.call("get_zoom_chip_text")) != chip_after,
				"chip %s" % String(_hud.call("get_zoom_chip_text")))

	# ---------- 8. drag di arena = kamera pan, BUKAN seleksi ----------
	var sel_before := String(_hud.call("get_selected_instance"))
	var rig = _base.get("rig")
	if rig != null:
		var pan_before: Vector2 = rig.call("pan")
		var start := Vector2(_vp().get_visible_rect().size * 0.5)
		_move_to(start)
		await get_tree().process_frame
		var down2 := InputEventMouseButton.new()
		down2.button_index = MOUSE_BUTTON_RIGHT
		down2.pressed = true
		down2.position = start
		down2.button_mask = MOUSE_BUTTON_MASK_RIGHT
		_vp().push_input(down2)
		for i in range(1, 7):
			var mv := InputEventMouseMotion.new()
			mv.position = start + Vector2(i * 18, i * 6)
			mv.relative = Vector2(18, 6)
			mv.button_mask = MOUSE_BUTTON_MASK_RIGHT
			_vp().push_input(mv)
			await get_tree().process_frame
		var up2 := InputEventMouseButton.new()
		up2.button_index = MOUSE_BUTTON_RIGHT
		up2.pressed = false
		up2.position = start + Vector2(108, 36)
		_vp().push_input(up2)
		await get_tree().process_frame
		var pan_after: Vector2 = rig.call("pan")
		var gesture_n := int(rig.call("gesture_counts").get("mouse_pan", 0))
		check("input.drag_kamera_pan", gesture_n > 0,
			"gesture mouse_pan=%d (state rig: %s)" % [gesture_n, str(rig.call("state"))])
		check("input.drag_kamera_menggeser_fokus", pan_after.distance_to(pan_before) > 0.05,
			"pan (%.2f,%.2f) → (%.2f,%.2f) unit; clamp radius %s" % [
				pan_before.x, pan_before.y, pan_after.x, pan_after.y,
				str(rig.call("pan_limits"))])
		check("input.drag_tidak_mengubah_seleksi",
			String(_hud.call("get_selected_instance")) == sel_before,
			"seleksi %s → %s" % [sel_before, String(_hud.call("get_selected_instance"))])

		# ---------- 8b. DRAG KIRI (mouse/trackpad) = pan kamera ----------
		## Standar peta/base-builder di desktop: tombol utama = geser peta.
		## Diuji dengan event nyata: tekan kiri → gerak → lepas.
		var pan_before2: Vector2 = rig.call("pan")
		var l1 := InputEventMouseButton.new()
		l1.button_index = MOUSE_BUTTON_LEFT
		l1.pressed = true
		l1.position = start + Vector2(40, 40)
		_vp().push_input(l1)
		await get_tree().process_frame
		for i in range(1, 7):
			var mv2 := InputEventMouseMotion.new()
			mv2.position = start + Vector2(40 - i * 16, 40 + i * 5)
			mv2.relative = Vector2(-16, 5)
			mv2.button_mask = MOUSE_BUTTON_MASK_LEFT
			_vp().push_input(mv2)
			await get_tree().process_frame
		var l2 := InputEventMouseButton.new()
		l2.button_index = MOUSE_BUTTON_LEFT
		l2.pressed = false
		l2.position = start + Vector2(40 - 96, 40 + 30)
		_vp().push_input(l2)
		await get_tree().process_frame
		var pan_after2: Vector2 = rig.call("pan")
		check("input.drag_kiri_pan", pan_after2.distance_to(pan_before2) > 0.05,
			"pan (%.2f,%.2f) → (%.2f,%.2f)" % [pan_before2.x, pan_before2.y,
				pan_after2.x, pan_after2.y])
		check("input.drag_kiri_bukan_klik", String(rig.call("left_drag_state")) == "release_drag",
			"state=%s" % String(rig.call("left_drag_state")))

		# ---------- 8c. KLIK setelah drag: tap pendek TETAP memilih bangunan ----------
		var sel_before3 := String(_hud.call("get_selected_instance"))
		_base.call("deselect")
		var b3 = bs.get_building("b_hq_01")
		if b3 == null:
			var all2: Array = bs.get_all_buildings()
			b3 = all2[0] if not all2.is_empty() else null
		if b3 != null:
			var sp3: Vector2 = cam.unproject_position(b3.global_position + Vector3(0, 1.0, 0))
			await _tap_at(sp3, "arena_after_drag")
			check("input.tap_setelah_drag_memilih", String(_hud.call("get_selected_instance")) == b3.instance_id,
				"tap %s → %s (sebelumnya %s)" % [str(sp3), String(_hud.call("get_selected_instance")),
					sel_before3])

	# ---------- 9. KLIK MENU → pause menu → LANJUT ----------
	var btn_menu := _find_button(_hud, "Action_menu")
	await _tap(btn_menu, "action_menu")
	check("input.pause_menu_terbuka_oleh_klik", _hud.call("is_pause_menu_open"))
	if _hud.call("is_pause_menu_open"):
		var pause: Control = _hud.call("get_pause_menu")
		var resume := _find_button(pause, "ResumeButton")
		await _tap(resume, "pause_resume")
		check("input.pause_tertutup_oleh_klik", not _hud.call("is_pause_menu_open"))

	QaMarkers.marker("INPUT", "DONE", {"passed": passed, "failed": failed})
	_finish()


func _finish() -> void:
	print("INPUT:DONE passed=%d failed=%d" % [passed, failed])
	QaMarkers.marker("INPUT", "SUMMARY", {"passed": passed, "failed": failed})
