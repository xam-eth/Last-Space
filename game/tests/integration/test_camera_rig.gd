extends RefCounted
## TestCameraRig — M3 #6: zoom & pan kamera Command Mode. Ekspektasi dari nilai
## AKTUAL rig (clamp, dolly, pan radius) + event input nyata (wheel, drag,
## pinch, double tap, tombol keyboard). SINKRON: runner test tidak menunggu frame
## (pelajaran M3 #5: `await` di suite = cek setelahnya hilang senyap).

const RIG := "res://scripts/ui/camera_rig.gd"
const BASE_POS := Vector3(0, 15, -21)
const FOCUS := Vector3(0, 2.6, 6)


func run(t) -> void:
	TestUtil.reset_all()
	var tree := Engine.get_main_loop() as SceneTree
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.position = BASE_POS
	cam.look_at(FOCUS, Vector3.UP)
	var rig = load(RIG).new()
	tree.root.add_child(rig)
	rig.setup(cam, BASE_POS, FOCUS)
	var base_dist: float = BASE_POS.distance_to(FOCUS)

	# --- default: zoom 1,0 → jarak = jarak dasar, kamera di posisi dasar ---
	t.check_eq("cam.default_zoom", 1.0, rig.zoom())
	t.check_eq("cam.default_scale", 1.0, rig.scale())
	t.check("cam.default_pan", rig.pan() == Vector2.ZERO, str(rig.pan()))
	rig.apply_now()
	t.check("cam.apply_position",
		cam.global_position.distance_to(BASE_POS) < 0.01,
		"pos=%s (harap %s)" % [str(cam.global_position), str(BASE_POS)])
	t.check("cam.dolly_distance",
		absf(cam.global_position.distance_to(FOCUS) - base_dist) < 0.05,
		"jarak=%.2f (dasar %.2f)" % [cam.global_position.distance_to(FOCUS), base_dist])

	# --- clamp zoom (batas = kontrak rig, bukan angka test) ---
	var b: Dictionary = rig.bounds()
	rig.set_zoom_raw(0.01)
	t.check_eq("cam.clamp_close", float(b["zoom_close"]), rig.zoom())
	rig.set_zoom_raw(9.0)
	t.check_eq("cam.clamp_far", float(b["zoom_far"]), rig.zoom())
	rig.set_zoom_raw(1.0)

	# --- zoom in/out + scale_by + set_scale ---
	rig.zoom_in(0.2)
	t.check("cam.zoom_in_step", absf(rig.zoom() - 0.8) < 0.001, "zoom=%.3f" % rig.zoom())
	rig.zoom_out(0.2)
	t.check("cam.zoom_out_step", absf(rig.zoom() - 1.0) < 0.001, "zoom=%.3f" % rig.zoom())
	rig.scale_by(2.0)
	t.check("cam.scale_by_closer", rig.zoom() < 1.0 and absf(rig.scale() - 2.0) < 0.01,
		"scale=%.2f zoom=%.3f" % [rig.scale(), rig.zoom()])
	rig.set_scale(1.6)
	t.check("cam.set_scale", absf(rig.zoom() - 0.625) < 0.002, "zoom=%.3f" % rig.zoom())
	rig.apply_now()
	t.check("cam.close_distance_shorter",
		cam.global_position.distance_to(FOCUS) < base_dist,
		"jarak=%.2f < dasar %.2f" % [cam.global_position.distance_to(FOCUS), base_dist])
	t.check("cam.camera_above_ground", cam.global_position.y > 0.5,
		"y=%.2f" % cam.global_position.y)

	# --- pan: clamp radius (jangan keluar arena) ---
	rig.pan_by_world(100.0, 100.0)
	var r := float(b["pan_radius"])
	t.check("cam.pan_clamped", absf(rig.pan().length() - r) < 0.01,
		"|pan|=%.2f (batas %.1f)" % [rig.pan().length(), r])
	## Geser kecil di dalam radius = diterapkan apa adanya (tanpa clamp).
	rig.set_pan_raw(Vector2(2.0, 0.0))
	rig.pan_by_world(0.5, -0.5)
	t.check("cam.pan_delta_applied",
		absf(rig.pan().x - 2.5) < 0.001 and absf(rig.pan().y + 0.5) < 0.001,
		str(rig.pan()))
	rig.reset()
	t.check_eq("cam.reset_zoom", 1.0, rig.zoom())
	t.check("cam.reset_pan", rig.pan() == Vector2.ZERO, str(rig.pan()))

	# --- wheel (desktop/web): zoom, dan event DIKONSUMSI ---
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var consumed: bool = rig.handle_event(wheel)
	t.check("cam.wheel_consumed", consumed)
	t.check("cam.wheel_zoom_in", rig.zoom() < 1.0, "zoom=%.3f" % rig.zoom())
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rig.handle_event(wheel)
	t.check("cam.wheel_zoom_out", absf(rig.zoom() - 1.0) < 0.001, "zoom=%.3f" % rig.zoom())

	# --- drag tombol kanan = pan (konsumsi), tombol kiri = bukan gesture ---
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	rmb.position = Vector2(400, 300)
	t.check("cam.rmb_consumed", rig.handle_event(rmb))
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(460, 340)
	mm.button_mask = MOUSE_BUTTON_MASK_RIGHT
	t.check("cam.rmb_drag_consumed", rig.handle_event(mm))
	t.check("cam.rmb_drag_pans", rig.pan() != Vector2.ZERO, str(rig.pan()))
	rmb.pressed = false
	rig.handle_event(rmb)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	lmb.position = Vector2(400, 300)
	t.check("cam.lmb_not_gesture", not rig.handle_event(lmb))
	rig.reset()

	# --- touch: tap pendek TIDAK dikonsumsi (bangunan tetap bisa dipilih) ---
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = Vector2(500, 300)
	t.check("cam.tap_press_not_consumed", not rig.handle_event(tap))
	tap.pressed = false
	t.check("cam.tap_release_not_consumed", not rig.handle_event(tap))
	# --- double tap: konsumsi + toggle level zoom (Material) ---
	var tap2 := InputEventScreenTouch.new()
	tap2.index = 0
	tap2.pressed = true
	tap2.position = Vector2(502, 302)
	rig.handle_event(tap2)
	tap2.pressed = false
	t.check("cam.double_tap_consumed", rig.handle_event(tap2))
	t.check("cam.double_tap_close", absf(rig.zoom() - float(b["close_level"])) < 0.001,
		"zoom=%.3f (harap %.2f)" % [rig.zoom(), float(b["close_level"])])
	## Toggle kembali ke Normal butuh DUA tap lagi (satu tap hanya dicatat,
	## supaya tap tunggal tetap bisa memilih bangunan).
	for i in 2:
		var tap3 := InputEventScreenTouch.new()
		tap3.index = 0
		tap3.pressed = true
		tap3.position = Vector2(500, 300)
		rig.handle_event(tap3)
		tap3.pressed = false
		rig.handle_event(tap3)
	t.check("cam.double_tap_back_normal", absf(rig.zoom() - 1.0) < 0.001,
		"zoom=%.3f" % rig.zoom())

	# --- drag satu jari: di bawah ambang = tap, di atas = pan ---
	var drag := InputEventScreenTouch.new()
	drag.index = 0
	drag.pressed = true
	drag.position = Vector2(600, 400)
	rig.handle_event(drag)
	var small := InputEventScreenDrag.new()
	small.index = 0
	small.position = Vector2(606, 404)  ## 7 px < ambang 14
	t.check("cam.small_move_not_pan", not rig.handle_event(small))
	var big := InputEventScreenDrag.new()
	big.index = 0
	big.position = Vector2(660, 440)  ## jauh > ambang
	t.check("cam.drag_becomes_pan", rig.handle_event(big))
	t.check("cam.drag_changed_pan", rig.pan() != Vector2.ZERO, str(rig.pan()))
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = Vector2(660, 440)
	t.check("cam.drag_release_consumed", rig.handle_event(up))  ## tidak boleh jadi pick
	rig.reset()

	# --- pinch dua jari: menjauh = zoom in (lebih dekat), merapat = zoom out ---
	var f1 := InputEventScreenTouch.new()
	f1.index = 0
	f1.pressed = true
	f1.position = Vector2(500, 300)
	var f2 := InputEventScreenTouch.new()
	f2.index = 1
	f2.pressed = true
	f2.position = Vector2(600, 300)
	rig.handle_event(f1)
	t.check("cam.pinch_press_consumed", rig.handle_event(f2))
	var d1 := InputEventScreenDrag.new()
	d1.index = 1
	d1.position = Vector2(700, 300)  ## menjauh 100 → 200 px
	rig.handle_event(d1)
	t.check("cam.pinch_open_zoom_in", rig.zoom() < 1.0, "zoom=%.3f" % rig.zoom())
	var z_after_open: float = rig.zoom()
	var d2 := InputEventScreenDrag.new()
	d2.index = 1
	d2.position = Vector2(600, 300)  ## merapat kembali
	rig.handle_event(d2)
	t.check("cam.pinch_close_zoom_out", rig.zoom() > z_after_open,
		"zoom %.3f → %.3f" % [z_after_open, rig.zoom()])
	rig.reset()

	# --- keyboard + tombol HUD (satu jalur: EventBus) ---
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_EQUAL
	t.check("cam.key_zoom_in_consumed", rig.handle_event(key))
	t.check("cam.key_zoom_in", rig.zoom() < 1.0, "zoom=%.3f" % rig.zoom())
	var z_in: float = rig.zoom()
	key.keycode = KEY_MINUS
	t.check("cam.key_zoom_out_consumed", rig.handle_event(key))
	t.check("cam.key_zoom_out", rig.zoom() > z_in,
		"zoom %.3f → %.3f (menjauh)" % [z_in, rig.zoom()])
	key.keycode = KEY_0
	rig.handle_event(key)
	t.check_eq("cam.key_reset", 1.0, rig.zoom())

	# --- gesture tercatat (bukti marker/test, bukan klaim) ---
	var g: Dictionary = rig.gesture_counts()
	for kind in ["wheel_in", "wheel_out", "mouse_pan", "double_tap", "drag_start",
			"pinch", "two_finger_pan", "key_in", "key_out", "reset"]:
		t.check("cam.gesture_%s" % kind, int(g.get(kind, 0)) > 0, "count=%d" % int(g.get(kind, 0)))

	# --- world-per-pixel: drag 100 px menggeser fokus sebesar ~k×100 (terukur) ---
	rig.reset()
	rig.apply_now()
	var vp_h := float(tree.root.get_visible_rect().size.y)
	var k := 2.0 * base_dist * tan(deg_to_rad(cam.fov * 0.5)) / maxf(1.0, vp_h)
	rig.set_pan_raw(Vector2.ZERO)
	rig._pan_by_screen(Vector2(100.0, 0.0))
	var moved: float = rig.pan().length()
	t.check("cam.pan_screen_scale", absf(moved - k * 100.0) < k * 100.0 * 0.25,
		"geser=%.2f unit (harap ≈%.2f)" % [moved, k * 100.0])

	rig.queue_free()
	cam.queue_free()
