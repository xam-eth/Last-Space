extends Node
## CameraShowcase — M3 #6 (zoom & pan kamera Command Mode) di BUILD NYATA
## (mode `?mode=camera`). Membuktikan hal-hal yang tidak bisa dibuktikan unit test:
##   1. tombol HUD nyata (ZoomInButton / − / chip reset) memindahkan kamera &
##      chip mencerminkan state nyata ("x1,0" → "x1,6" → …);
##   2. jarak PIKsel antar landmark dunia ikut zoom (dolly) — rasio ≈ 1/zoom;
##   3. gesture (wheel, double tap, pinch, drag) lewat jalur input nyata;
##   4. setelah pan, tap pendek MASIH memilih bangunan (tidak direbut gesture);
##   5. HUD tetap tanpa tumpukan dengan cluster zoom baru (QA:HUD:OVERLAP).
##
## Langkah (shell: ?mode=camera&step=<x>) — tiap langkah berhenti di satu state
## untuk difoto: default | close | far | pan | auto (gate).

var passed := 0
var failed := 0
var _step := "auto"
var _base: Node
var _hud: Node


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func _ready() -> void:
	_step = "auto"
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--step="):
			_step = a.substr(7)
	await get_tree().process_frame
	await get_tree().process_frame
	_base = _find_base()
	_hud = _base.get_node_or_null("HUD/HUDControl") if _base != null else null
	if _base == null or _hud == null:
		check("cam.showcase_scene", false, "base/HUD tidak ditemukan")
		_finish()
		return
	if _step == "auto":
		await _run_checks()
	else:
		await _run_step(_step)
	_finish()


func _find_base() -> Node:
	for c in get_parent().get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("base_scene.gd"):
			return c
	return null


# --------------------------------------------------------------- langkah ----
func _run_step(step: String) -> void:
	var rig = _base.get("rig")
	match step:
		"default":
			_base.call("camera_reset")
		"close":
			_base.call("camera_set_scale", 1.6)      ## 1,6× lebih dekat
		"far":
			_base.call("camera_set_scale", 0.625)    ## 1,6× lebih jauh
		"pan":
			_base.call("camera_reset")
			_base.call("camera_pan_world", 9.0, -7.0)
		_:
			_base.call("camera_reset")
	await get_tree().process_frame
	QaMarkers.marker("CAM", "STEP", {"step": step, "state": rig.state(),
		"chip": _hud.call("get_zoom_chip_text")})
	await get_tree().create_timer(0.6).timeout  ## settle untuk screenshot
	## Deklutter label berjalan 20 Hz → beri 2 tick supaya state label final.
	await get_tree().create_timer(0.15).timeout
	var lab: Dictionary = _base.call("audit_label_hud_overlap")
	QaMarkers.marker("CAM", "LABEL_CHECK", {"step": step, "zoom": snappedf(rig.zoom(), 0.01),
		"overlap": int(lab["overlap"]), "visible": int(lab["visible"]),
		"hidden": int(lab["hidden"]), "zones": int(lab["zones"])})
	QaMarkers.marker("CAM", "STEP_READY", {"step": step})


# ---------------------------------------------------------------- cek -------
func _run_checks() -> void:
	var rig = _base.get("rig")
	check("cam.rig_ready", rig != null)
	if rig == null:
		return
	# --- state awal kanonik ---
	_base.call("camera_reset")
	await get_tree().process_frame
	check("cam.default_scale", absf(rig.scale() - 1.0) < 0.01, "scale=%.2f" % rig.scale())
	check("cam.chip_default", String(_hud.call("get_zoom_chip_text")) == "x1,0",
		"chip=%s" % _hud.call("get_zoom_chip_text"))
	var d0: float = _landmark_span()
	QaMarkers.marker("CAM", "SPAN", {"scale": snappedf(rig.scale(), 0.01),
		"px": snappedf(d0, 0.1)})

	# --- tombol HUD nyata: zoom in 2× (klik sungguhan lewat pressed) ---
	var btn_in := _hud.get_node_or_null("ZoomCluster/ZoomInButton") as Button
	var btn_out := _hud.get_node_or_null("ZoomCluster/ZoomOutButton") as Button
	var chip := _hud.get_node_or_null("ZoomCluster/ZoomChip") as Button
	check("cam.hud_buttons_exist", btn_in != null and btn_out != null and chip != null)
	if btn_in == null:
		return
	check("cam.hud_button_size_48dp",
		btn_in.custom_minimum_size.x >= 96.0 and btn_in.custom_minimum_size.y >= 96.0,
		"min=%.0fx%.0f px (96 = 48dp)" % [btn_in.custom_minimum_size.x,
			btn_in.custom_minimum_size.y])
	check("cam.hud_button_labeled", btn_in.text != "" and btn_out.text != "" and chip.text != "",
		"+/−/chip punya teks (%s, %s, %s)" % [btn_in.text, btn_out.text, chip.text])
	for i in 2:
		btn_in.pressed.emit()
		await get_tree().process_frame
	var s_close: float = rig.scale()
	var d_close: float = _landmark_span()
	check("cam.button_zoom_in_moves_camera", d_close > d0,
		"span %.1f → %.1f px (kamera lebih dekat)" % [d0, d_close])
	check("cam.button_zoom_in_ratio", d_close / maxf(1.0, d0) >= 1.30,
		"rasio=%.2f (harap ≥1,30 untuk 2 langkah ÷0,76)" % (d_close / maxf(1.0, d0)))
	check("cam.chip_updates", String(_hud.call("get_zoom_chip_text")) != "x1,0",
		"chip=%s" % _hud.call("get_zoom_chip_text"))
	QaMarkers.marker("CAM", "SPAN", {"scale": snappedf(s_close, 0.01),
		"px": snappedf(d_close, 0.1), "via": "button"})

	# --- chip = reset (state nyata) ---
	chip.pressed.emit()
	await get_tree().process_frame
	check("cam.chip_reset", absf(rig.scale() - 1.0) < 0.01, "scale=%.2f" % rig.scale())
	check("cam.chip_reset_text", String(_hud.call("get_zoom_chip_text")) == "x1,0",
		"chip=%s" % _hud.call("get_zoom_chip_text"))

	# --- zoom out (tombol −) → landmark mengecil ---
	btn_out.pressed.emit()
	await get_tree().process_frame
	var d_far: float = _landmark_span()
	check("cam.button_zoom_out", d_far < d0,
		"span %.1f → %.1f px (kamera lebih jauh)" % [d0, d_far])
	_base.call("camera_reset")
	await get_tree().process_frame

	# --- gesture nyata lewat rig.handle_event ---
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	check("cam.gesture_wheel", rig.handle_event(wheel) and rig.zoom() < 1.0,
		"zoom=%.3f" % rig.zoom())
	rig.reset()
	# double tap (dua tap cepat) → level Dekat
	for i in 2:
		var tp := InputEventScreenTouch.new()
		tp.index = 0
		tp.pressed = true
		tp.position = Vector2(640, 400)
		rig.handle_event(tp)
		tp.pressed = false
		rig.handle_event(tp)
	await get_tree().process_frame
	check("cam.gesture_double_tap_close", rig.zoom() < 0.8, "zoom=%.3f" % rig.zoom())
	# pinch dua jari (menjauh = zoom in)
	rig.reset()
	var f1 := InputEventScreenTouch.new()
	f1.index = 0
	f1.pressed = true
	f1.position = Vector2(500, 300)
	var f2 := InputEventScreenTouch.new()
	f2.index = 1
	f2.pressed = true
	f2.position = Vector2(700, 300)
	rig.handle_event(f1)
	rig.handle_event(f2)
	var dg := InputEventScreenDrag.new()
	dg.index = 1
	dg.position = Vector2(900, 300)
	rig.handle_event(dg)
	check("cam.gesture_pinch", rig.zoom() < 1.0, "zoom=%.3f" % rig.zoom())
	rig.reset()
	QaMarkers.marker("CAM", "GESTURES", rig.gesture_counts())

	# --- pan: kamera bergeser & dibatasi; tap MASIH memilih bangunan ---
	var before := (_base.get("camera") as Camera3D).global_position
	_base.call("camera_pan_world", 6.0, -4.0)
	await get_tree().process_frame
	var after := (_base.get("camera") as Camera3D).global_position
	check("cam.pan_moves_camera", after.distance_to(before) > 1.0,
		"Δ=%.2f unit" % after.distance_to(before))
	_base.call("camera_pan_world", 999.0, 999.0)
	var r := float(rig.bounds()["pan_radius"])
	check("cam.pan_clamped", rig.pan().length() <= r + 0.01,
		"|pan|=%.2f (batas %.1f)" % [rig.pan().length(), r])
	# tap pendek pada posisi layar bangunan → terpilih (gesture tidak merebut tap)
	_base.call("camera_reset")
	await get_tree().process_frame
	var bs := _base.get_node("BuildingSystem")
	var b = bs.get_building("b_hq_01")
	if b == null:
		var all: Array = bs.get_all_buildings()
		b = all[0] if not all.is_empty() else null
	var pick_ok := false
	var pick_detail := "tidak ada bangunan"
	if b != null:
		var cam := _base.get("camera") as Camera3D
		var sp: Vector2 = cam.unproject_position(b.global_position + Vector3(0, 1.0, 0))
		_base.call("_pick", sp)
		pick_ok = String(_base.get("_arrow_target")) == b.instance_id
		pick_detail = "tap di %s → %s" % [str(sp), b.instance_id]
	check("cam.tap_selects_after_pan", pick_ok, pick_detail)
	_base.call("deselect")

	# --- zoom dekat: label dunia TIDAK boleh menembus panel HUD (kritik #3) ---
	_base.call("camera_set_scale", 1.61)
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout  ## 2+ tick deklutter
	var lab: Dictionary = _base.call("audit_label_hud_overlap")
	check("cam.close_label_no_hud_overlap", int(lab["overlap"]) == 0,
		"label terlihat=%d hidden=%d zona=%d" % [int(lab["visible"]),
			int(lab["hidden"]), int(lab["zones"])])
	QaMarkers.marker("CAM", "LABEL_CHECK", {"step": "checks", "zoom": snappedf(rig.zoom(), 0.01),
		"overlap": int(lab["overlap"]), "visible": int(lab["visible"]),
		"hidden": int(lab["hidden"]), "zones": int(lab["zones"])})
	_base.call("camera_reset")
	await get_tree().process_frame

	# --- HUD tanpa tumpukan dengan cluster zoom (audit ulang, data nyata) ---
	_hud.call("_dump_layout")
	await get_tree().process_frame
	await get_tree().process_frame
	QaMarkers.marker("CAM", "HUD_AUDIT", {"chip": _hud.call("get_zoom_chip_text")})


## Jarak piksel antara dua landmark dunia (HQ vs bangunan terjauh) → bukti
## dolly: kamera lebih dekat = jarak layar membesar.
func _landmark_span() -> float:
	## Dua titik dunia TETAP (arena markas 14×12 unit) diproyeksikan ke layar —
	## bukan bangunan pemain (gameplay hanya menempatkan HQ saat mulai; temuan
	## gate: span=0 karena hanya 1 bangunan ada).
	var cam := _base.get("camera") as Camera3D
	var a: Vector2 = cam.unproject_position(Vector3(-7.0, 1.0, -6.0))
	var b: Vector2 = cam.unproject_position(Vector3(7.0, 1.0, 6.0))
	return a.distance_to(b)


func _finish() -> void:
	print("CAMERA:DONE passed=%d failed=%d" % [passed, failed])
	QaMarkers.marker("CAMERA", "DONE", {"passed": passed, "failed": failed, "step": _step})
