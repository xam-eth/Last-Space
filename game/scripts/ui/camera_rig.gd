class_name CameraRig
extends Node
## CameraRig — kontrol kamera Command Mode (M3 #6): ZOOM + PAN.
##
## Standar gesture (riset, bukan asumsi — Material Design "Gestures", bagian
## Navigational gestures: Pan / Pinch / Double tap):
##   - Pinch open/closed  : zoom in/out kontinu ("a gradient of zoom levels")
##   - Drag satu jari     : pan ("a pan is an omnidirectional one- or two-finger
##                          gesture… drag is typically used with pan")
##   - Double tap         : "toggle between zoom levels" (Normal <-> Dekat)
##   - Tombol eksplisit   : gesture "supplement other explicit input methods,
##                          like buttons" → HUD punya tombol + / x1,0 / −
## Desktop/web (QA & pemain mouse): wheel = zoom, DRAG KIRI = pan (pola peta/
## base-builder: menggeser peta dengan tombol utama), drag tombol kanan/tengah = pan,
## tombol keyboard `+`/`-`/`0` = zoom in/out/reset (dipakai juga oleh test).
##
## Model zoom = DOLLY sepanjang sumbu pandang (bukan FOV, supaya perspektif
## bangunan tidak berubah drastis): jarak = jarak_dasar × `zoom`.
##   zoom < 1 → lebih dekat (bangunan lebih besar di layar)
##   zoom > 1 → lebih jauh
## Nilai `zoom` adalah pengali jarak; UI menampilkan kebalikannya (`scale` = 1/zoom)
## supaya pemain membaca "×1,6" = 1,6× lebih dekat.
##
## Batas gerak (M3 #8, riset teknis base-builder — bukan angka kira-kira):
##   - Pan TIDAK dibatasi radius arbitrer, tapi oleh **frustum di bidang tanah**:
##     kamera tidak boleh memandang lewat tepi daratan ("viewport frustum bounding
##     prevents seeing past ground borders", pola CoC-like camera). Empat sudut
##     viewport di-unproject ke plane y=0 → kotak pandang nyata; fokus di-clamp
##     supaya kotak itu selalu di dalam batas arena. Berlaku juga saat zoom dekat.
##   - Zoom maksimum DIHITUNG dari geometri (fov kamera + aspek viewport + ukuran
##     arena), bukan konstanta: `zoom_fit()` mencari jarak terkecil yang membuat
##     SELURUH arena masuk layar, sehingga di portrait 9:19,5 pemain tetap bisa
##     melihat seluruh basis (temuan: zoom far 1,90× tidak cukup di portrait).
##   - Setiap perubahan ukuran viewport (rotasi) menghitung ulang batas & fit.
##
## `handle_event()` mengembalikan true bila event DIKONSUMSI sebagai gesture →
## base_scene tidak melakukan pick bangunan (tap pendek tetap tembus ke pick).

const ZOOM_CLOSE := 0.45   ## terdekat (dolly 45% jarak dasar)
const ZOOM_FAR_MIN := 1.90 ## terjauh MINIMUM; bisa naik bila geometri menuntut
const ZOOM_FAR_MAX := 4.00 ## batas absolut (jaring pengaman, tetap ada clamp)
const ZOOM_DEFAULT := 1.0
const ZOOM_STEP := 0.12    ## satu notch wheel
const CLOSE_LEVEL := 0.62  ## level "Dekat" untuk double tap
const DRAG_THRESHOLD_PX := 14.0   ## di bawah ini = tap (bukan pan)
const DOUBLE_TAP_MS := 320
const DOUBLE_TAP_PX := 48.0
const ARENA_MARGIN := 0.985  ## toleransi: kotak pandang boleh lebih kecil 1,5%
const SMOOTH := 14.0       ## kecepatan smoothing (1/detik)
const CAM_MIN_Y := 2.5     ## kamera tidak boleh menembus lantai

var camera: Camera3D = null
var _focus_base := Vector3.ZERO
var _base_pos := Vector3.ZERO
var _base_dist := 1.0
var _view_dir := Vector3.FORWARD

var _zoom := ZOOM_DEFAULT
var _zoom_far := ZOOM_FAR_MIN     ## batas zoom jauh nyata (dihitung dari geometri)
var _arena_min := Vector2(-40.0, -40.0)  ## batas daratan XZ (di-set base_scene)
var _arena_max := Vector2(40.0, 40.0)
var _extents := Vector4.ZERO      ## kotak pandang di plane y=0 relatif fokus
var _extents_zoom := -1.0         ## zoom saat _extents dihitung (cache)
var _pan := Vector2.ZERO          ## offset fokus pada XZ
var _zoom_cur := ZOOM_DEFAULT
var _pan_cur := Vector2.ZERO
var _dirty := true
var _emit_t := 0.0
var _last_emit := Vector3(-999.0, -999.0, 0.0)  ## zoom, pan.x, pan.y

# --- state gesture ---
var _touches: Dictionary = {}     ## index -> posisi (px)
var _drag_start := Vector2.ZERO
var _dragged := false
var _pinch_dist := -1.0
var _pinch_center := Vector2.ZERO
var _mouse_pan := false
var _left_down := false          ## tombol kiri (web/mouse) — drag = pan
var _left_dragged := false       ## kiri sudah melewati ambang → BUKAN tap
var _left_hint := ""             ## jejak untuk marker
var _mouse_last := Vector2.ZERO
var _last_tap_ms := -10000
var _last_tap_pos := Vector2.ZERO
var _gestures: Dictionary = {}    ## nama gesture -> jumlah (bukti marker/test)


func setup(p_camera: Camera3D, base_pos: Vector3, focus: Vector3) -> void:
	camera = p_camera
	_base_pos = base_pos
	_focus_base = focus
	_view_dir = (base_pos - focus).normalized()
	_base_dist = base_pos.distance_to(focus)
	_zoom = ZOOM_DEFAULT
	_pan = Vector2.ZERO
	_zoom_cur = _zoom
	_pan_cur = _pan
	_dirty = true
	_refresh_geometry()
	QaMarkers.marker("CAM", "READY", state())
	QaMarkers.marker("CAM", "BOUNDS", {"arena_min": [_arena_min.x, _arena_min.y],
		"arena_max": [_arena_max.x, _arena_max.y], "zoom_far": snappedf(_zoom_far, 0.001),
		"zoom_far_min": ZOOM_FAR_MIN, "zoom_far_max": ZOOM_FAR_MAX,
		"extents": [snappedf(_extents.x, 0.01), snappedf(_extents.y, 0.01),
			snappedf(_extents.z, 0.01), snappedf(_extents.w, 0.01)]})


# ---------------------------------------------------------------- getter ----
func zoom() -> float:
	return _zoom


func scale() -> float:
	## 1,0 = tampilan normal; >1 = lebih dekat (yang dibaca pemain).
	return 1.0 / maxf(0.01, _zoom)


func pan() -> Vector2:
	return _pan


func bounds() -> Dictionary:
	return {"zoom_close": ZOOM_CLOSE, "zoom_far": _zoom_far,
		"zoom_far_min": ZOOM_FAR_MIN, "zoom_far_max": ZOOM_FAR_MAX,
		"arena_min": [_arena_min.x, _arena_min.y],
		"arena_max": [_arena_max.x, _arena_max.y],
		"close_level": CLOSE_LEVEL}


func arena_bounds() -> Array:
	return [_arena_min, _arena_max]


func zoom_fit() -> float:
	return _zoom_far


func view_extents() -> Vector4:
	## (min_dx, max_dx, min_dz, max_dz) kotak pandang di plane y=0 relatif fokus.
	return _extents


func state() -> Dictionary:
	## `zoom` = target (kontrak API), `zoom_cur` = nilai berjalan (animasi halus)
	## — dilaporkan terpisah supaya marker tidak mencampur "mau ke mana" dan
	## "sedang di mana" (temuan: cam_y tampak aneh karena smoothing masih jalan).
	return {"zoom": snappedf(_zoom, 0.001), "zoom_cur": snappedf(_zoom_cur, 0.001),
		"zoom_far": snappedf(_zoom_far, 0.001),
		"scale": snappedf(scale(), 0.001),
		"pan_x": snappedf(_pan.x, 0.01), "pan_z": snappedf(_pan.y, 0.01),
		"dist": snappedf(_base_dist * _zoom, 0.01),
		"cam_y": snappedf(camera.global_position.y, 0.01) if camera != null else 0.0,
		"gestures": _gestures.duplicate()}


func left_drag_state() -> String:
	## "release_drag" = drag terakhir menelan klik (bukan tap) — bukti untuk gate.
	return _left_hint


func is_left_dragging() -> bool:
	return _left_dragged


func gesture_counts() -> Dictionary:
	return _gestures.duplicate()


func _count(kind: String) -> void:
	_gestures[kind] = int(_gestures.get(kind, 0)) + 1


# ------------------------------------------------------------------ ubah ----
func set_zoom_raw(z: float) -> void:
	## Instan (tanpa smoothing) — dipakai test & snapshot.
	var want := clampf(z, ZOOM_CLOSE, _zoom_far)
	if not is_equal_approx(want, z):
		## HANYA saat batas (bukan permintaan) yang menentukan → marker jujur.
		## (Temuan gate M3 #8: marker lama membandingkan nilai LAMA vs baru,
		## sehingga setiap zoom normal ikut dilaporkan "di-clamp" = menyesatkan.)
		QaMarkers.marker("CAM", "CLAMP", {"req": snappedf(z, 0.001),
			"got": snappedf(want, 0.001), "zoom_far": snappedf(_zoom_far, 0.001)})
	_zoom = want
	_pan = _clamp_pan(_pan)
	_pan_cur = _clamp_pan(_pan_cur)
	_zoom_cur = _zoom
	_dirty = true
	_emit(true)


func set_scale(s: float) -> void:
	set_zoom_raw(1.0 / maxf(0.01, s))


func scale_by(factor: float) -> void:
	set_zoom_raw(_zoom / maxf(0.01, factor))


func zoom_in(step: float = ZOOM_STEP * 2.0) -> void:
	set_zoom_raw(_zoom - step)


func zoom_out(step: float = ZOOM_STEP * 2.0) -> void:
	set_zoom_raw(_zoom + step)


func zoom_to_fit() -> void:
	## Village view: zoom ke batas terjauh (seluruh arena) — dipakai tombol
	## double-tap-out / test; tetap dihitung kamera (bukan angka tetap).
	set_zoom_raw(_zoom_far)


func set_pan_raw(p: Vector2) -> void:
	_pan = _clamp_pan(p)
	_pan_cur = _pan
	_dirty = true
	_emit(true)


func pan_by_world(dx: float, dz: float) -> void:
	set_pan_raw(_pan + Vector2(dx, dz))


func reset() -> void:
	set_zoom_raw(ZOOM_DEFAULT)
	set_pan_raw(Vector2.ZERO)
	_count("reset")


func configure_arena(center: Vector3, half: Vector2) -> void:
	## Batas daratan NYATA (dari scene: ukuran platform). Semua clamp & fit
	## memakai angka ini, jadi arena yang berubah ukuran tidak membuat kamera
	## salah batas (dan tidak ada radius ajaib di dalam rig).
	_focus_base = Vector3(center.x, _focus_base.y, center.z)
	_arena_min = Vector2(center.x - half.x, center.z - half.y)
	_arena_max = Vector2(center.x + half.x, center.z + half.y)
	_refresh_geometry()


func _refresh_geometry() -> void:
	## Hitung ulang (a) kotak pandang di bidang tanah untuk zoom saat ini dan
	## (b) zoom jauh maksimum agar seluruh arena muat. Dipanggil saat setup,
	## saat batas arena berubah, dan saat ukuran viewport berubah (rotasi).
	if camera == null:
		return
	var saved := camera.global_transform
	_ensure_extents(_zoom)
	var fit := _solve_zoom_fit()
	## zoom jauh = MAKS(fit geometris, batas minimum desain) supaya: (1) seluruh
	## arena selalu bisa dilihat (portrait 9:19,5 pun), (2) landscape tetap punya
	## rentang zoom yang sama seperti semula (tidak menyusut).
	_zoom_far = clampf(maxf(fit, ZOOM_FAR_MIN), ZOOM_CLOSE + 0.05, ZOOM_FAR_MAX)
	if _zoom > _zoom_far:
		_zoom = _zoom_far
		_zoom_cur = minf(_zoom_cur, _zoom_far)
	_pan = _clamp_pan(_pan)
	_pan_cur = _clamp_pan(_pan_cur)
	camera.global_transform = saved
	_dirty = true
	_emit(true)
	QaMarkers.marker("CAM", "GEOMETRY", {"zoom": snappedf(_zoom, 0.001),
		"zoom_far": snappedf(_zoom_far, 0.001), "fit_geometry": snappedf(fit, 0.001),
		"extents": [snappedf(_extents.x, 0.01), snappedf(_extents.y, 0.01),
			snappedf(_extents.z, 0.01), snappedf(_extents.w, 0.01)],
		"fits_all": _fits_all(_zoom)})


func on_viewport_resized() -> void:
	## Rotasi/resize layar: batas pandang & zoom fit berubah → hitung ulang.
	_refresh_geometry()


func _project_ground_quad(z: float, focus: Vector3) -> Vector4:
	## Kotak TANAH YANG BENAR-BENAR TERLIHAT pada zoom `z`: (min_dx, max_dx,
	## min_dz, max_dz) relatif fokus.
	##
	## Kenapa tidak unproject 4 sudut begitu saja: kamera Command menunduk hanya
	## ~25°, jadi sudut ATAS layar mengarah DI ATAS horizon (tidak memotong
	## tanah) — unproject sudut itu meleset jauh (temuan test: quad kedalaman
	## 0,000002 unit). Yang benar: telusuri kolom tengah dari baris BAWAH ke ATAS
	## dan berhenti di baris terakhir yang ray-nya masih menukik ke tanah; itulah
	## "tepi jauh" pandangan. Empat titik (kiri/kanan × baris jauh & baris bawah)
	## membentuk kotak pandangan tanah.
	if camera == null:
		return Vector4(-10.0, 10.0, -10.0, 10.0)
	var saved := camera.global_transform
	var dist := _base_dist * z
	camera.global_position = focus + _view_dir * dist
	camera.look_at(focus, Vector3.UP)
	var vp := camera.get_viewport()
	var size := vp.get_visible_rect().size if vp != null else Vector2(1280, 720)
	var far_row := size.y
	for i in range(65):
		var r := size.y - size.y * (float(i) / 64.0)
		var n := camera.project_ray_normal(Vector2(size.x * 0.5, r))
		if n.y < -0.05:
			far_row = r
		else:
			break
	if far_row >= size.y - 1.0:
		far_row = size.y * 0.5  ## kamera nyaris top-down: ambil baris tengah
	var min_dx := INF
	var max_dx := -INF
	var min_dz := INF
	var max_dz := -INF
	for corner in [Vector2(0, far_row), Vector2(size.x, far_row),
			Vector2(0, size.y), Vector2(size.x, size.y)]:
		var o := camera.project_ray_origin(corner)
		var n2 := camera.project_ray_normal(corner)
		if n2.y > -0.0001:
			continue
		var t := -o.y / n2.y
		if t <= 0.0:
			continue
		var p := o + n2 * t
		min_dx = minf(min_dx, p.x - focus.x)
		max_dx = maxf(max_dx, p.x - focus.x)
		min_dz = minf(min_dz, p.z - focus.z)
		max_dz = maxf(max_dz, p.z - focus.z)
	camera.global_transform = saved
	if min_dx == INF:
		return Vector4(-10.0, 10.0, -10.0, 10.0)
	return Vector4(min_dx, max_dx, min_dz, max_dz)


func _fits_all(z: float) -> bool:
	## Apakah SELURUH arena masuk layar pada zoom `z`? Diuji dengan MEMPROYEKSI
	## 4 sudut arena ke layar (project selalu terdefinisi, tidak bergantung
	## horizon) — margin 2% layar agar tepi tidak menempel bingkai.
	if camera == null:
		return false
	var saved := camera.global_transform
	var dist := _base_dist * z
	camera.global_position = _focus_base + _view_dir * dist
	camera.look_at(_focus_base, Vector3.UP)
	var vp := camera.get_viewport()
	var size := vp.get_visible_rect().size if vp != null else Vector2(1280, 720)
	var mx := size.x * 0.02
	var my := size.y * 0.02
	var ok := true
	for c in [Vector2(_arena_min.x, _arena_min.y), Vector2(_arena_max.x, _arena_min.y),
			Vector2(_arena_min.x, _arena_max.y), Vector2(_arena_max.x, _arena_max.y)]:
		var sp := camera.unproject_position(Vector3(c.x, 0.0, c.y))
		if sp.x < mx or sp.x > size.x - mx or sp.y < my or sp.y > size.y - my:
			ok = false
			break
	camera.global_transform = saved
	return ok


func _solve_zoom_fit() -> float:
	## Cari zoom jauh MINIMUM agar seluruh arena masuk: pandangan melebar monoton
	## terhadap jarak → binary search 26 iterasi (presisi < 0,001).
	var lo := ZOOM_CLOSE
	var hi := ZOOM_FAR_MAX
	if _fits_all(hi):
		for i in 26:
			var mid := (lo + hi) * 0.5
			if _fits_all(mid):
				hi = mid
			else:
				lo = mid
	return hi


func pan_limits() -> Vector4:
	## Rentang pan yang SAH = FOKUS di dalam plataran (min_x, max_x, min_z, max_z).
	## Fokus (titik yang dipandang) tidak boleh keluar dari daratan; ini yang
	## dijamin kamera. (Mengklaim "tidak ada tanah luar plataran yang terlihat"
	## TIDAK mungkin dengan kamera menunduk ~25°: cakrawala memang terlihat —
	## dilaporkan jujur di view_extents, bukan diklaim palsu.)
	return Vector4(_arena_min.x - _focus_base.x, _arena_max.x - _focus_base.x,
		_arena_min.y - _focus_base.z, _arena_max.y - _focus_base.z)


func view_quad_world() -> Rect2:
	## Kotak tanah yang benar-benar terlihat (info & laporan; dipakai untuk
	## mengukur seberapa jauh pandangan menjangkau, bukan untuk clamp fokus).
	_ensure_extents(_zoom)
	return Rect2(_focus_base.x + _pan.x + _extents.x, _focus_base.z + _pan.y + _extents.z,
		_extents.y - _extents.x, _extents.w - _extents.z)


func fits_all() -> bool:
	## Seluruh arena masuk layar pada zoom saat ini?
	return _fits_all(_zoom)


func inside_arena() -> bool:
	## Klaim yang DIUJI (dan dapat dijamin): fokus masih di dalam plataran,
	## dengan toleransi 0,05 unit.
	var lim := pan_limits()
	return _pan.x >= lim.x - 0.05 and _pan.x <= lim.y + 0.05 \
		and _pan.y >= lim.z - 0.05 and _pan.y <= lim.w + 0.05


func _ensure_extents(z: float) -> void:
	## Cache kotak pandangan tanah per-zoom: 5 ray unproject, jadi dihitung saat
	## zoom berubah saja (drag pan tidak memicu hitung ulang).
	if not is_equal_approx(z, _extents_zoom):
		_extents = _project_ground_quad(z, _focus_base)
		_extents_zoom = z


func _clamp_pan(p: Vector2) -> Vector2:
	## Clamp FOKUS ke dalam plataran (batas dari ukuran arena nyata, bukan radius
	## ajaib): kamera tidak pernah "keluar peta" walau pemain menggeser terus.
	var lim := pan_limits()
	return Vector2(clampf(p.x, lim.x, lim.y), clampf(p.y, lim.z, lim.w))


# ------------------------------------------------------------ gesture -------
func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion)
	if event is InputEventScreenTouch:
		return _handle_touch(event as InputEventScreenTouch)
	if event is InputEventScreenDrag:
		return _handle_drag(event as InputEventScreenDrag)
	if event is InputEventKey:
		return _handle_key(event as InputEventKey)
	return false


func _handle_mouse_button(mb: InputEventMouseButton) -> bool:
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP
			or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in(ZOOM_STEP)
			_count("wheel_in")
		else:
			zoom_out(ZOOM_STEP)
			_count("wheel_out")
		_ping("wheel")
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		_mouse_pan = mb.pressed
		_mouse_last = mb.position
		return true
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			## Kiri ditekan: belum tahu tap atau drag — tunggu gerakan.
			_left_down = true
			_left_dragged = false
			_left_hint = "press"
			_mouse_last = mb.position
			_drag_start = mb.position
			return false  ## press diteruskan (pick ditunda ke release)
		_left_down = false
		_drag_start = Vector2.ZERO
		var was_drag := _left_dragged
		_left_dragged = false
		if was_drag:
			_count("mouse_drag_pan")
			_ping("mouse_drag")
			_left_hint = "release_drag"
			return true  ## drag: JANGAN pick
		_left_hint = "release_tap"
		return false  ## tap: teruskan → base_scene pick
	return false


func _handle_mouse_motion(mm: InputEventMouseMotion) -> bool:
	if _left_down and mm.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		if not _left_dragged:
			if mm.position.distance_to(_drag_start) > DRAG_THRESHOLD_PX:
				_left_dragged = true
				_count("mouse_drag_start")
		if _left_dragged:
			_pan_by_screen(mm.position - _mouse_last)
			_mouse_last = mm.position
			_count("mouse_pan")
			_ping("mouse_pan")
			return true
		_mouse_last = mm.position
		return false
	if not _mouse_pan:
		return false
	if mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE) == 0:
		return false
	_pan_by_screen(mm.position - _mouse_last)
	_mouse_last = mm.position
	_count("mouse_pan")
	_ping("mouse_pan")
	return true


func _handle_touch(st: InputEventScreenTouch) -> bool:
	if st.pressed:
		_touches[st.index] = st.position
		if _touches.size() == 1:
			_drag_start = st.position
			_dragged = false
		elif _touches.size() == 2:
			_dragged = true  ## dua jari bukan tap
			## Baseline pinch diambil SAAT jari kedua mendarat — kalau tidak,
			## jari pertama yang langsung bergerak tidak menghasilkan zoom
			## (temuan test cam.pinch_open_zoom_in).
			var ks := _touches.keys()
			ks.sort()
			var pa: Vector2 = _touches[ks[0]]
			var pb: Vector2 = _touches[ks[1]]
			_pinch_dist = pa.distance_to(pb)
			_pinch_center = (pa + pb) * 0.5
		return _touches.size() >= 2
	# --- release ---
	_touches.erase(st.index)
	if _touches.size() < 2:
		_pinch_dist = -1.0
	if _dragged:
		_dragged = false
		_count("drag_end")
		return true
	## Tap pendek: double tap = toggle level zoom (Material: "double taps allow
	## users to zoom into content, or toggle between zoom levels").
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms <= DOUBLE_TAP_MS and st.position.distance_to(_last_tap_pos) <= DOUBLE_TAP_PX:
		_toggle_zoom()
		_last_tap_ms = -10000
		_count("double_tap")
		_ping("double_tap")
		return true
	_last_tap_ms = now
	_last_tap_pos = st.position
	return false  ## tap tetap diteruskan → pick bangunan


func _handle_drag(sd: InputEventScreenDrag) -> bool:
	var prev: Variant = _touches.get(sd.index, null)
	_touches[sd.index] = sd.position
	if _touches.size() >= 2:
		## Pinch (zoom) + pan dua jari. Center dihitung dari kedua sentuhan.
		var keys := _touches.keys()
		keys.sort()
		var a: Vector2 = _touches[keys[0]]
		var b: Vector2 = _touches[keys[1]]
		var dist := a.distance_to(b)
		var center := (a + b) * 0.5
		if _pinch_dist > 1.0 and dist > 1.0:
			## pinch open (dist membesar) = zoom in (jarak kamera mengecil)
			set_zoom_raw(_zoom * (_pinch_dist / dist))
			_count("pinch")
			_ping("pinch")
		if _pinch_dist > 0.0:
			_pan_by_screen(center - _pinch_center)
			_count("two_finger_pan")
		_pinch_dist = dist
		_pinch_center = center
		return true
	if prev == null:
		return false
	## Satu jari: tunda keputusan sampai melewati ambang drag (tap < ambang).
	if not _dragged and sd.position.distance_to(_drag_start) > DRAG_THRESHOLD_PX:
		_dragged = true
		_count("drag_start")
		_ping("drag")
	if _dragged:
		_pan_by_screen(sd.position - (prev as Vector2))
		return true
	return false


func _handle_key(k: InputEventKey) -> bool:
	if not k.pressed or k.echo:
		return false
	match k.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_in()
			_count("key_in")
			_ping("key")
			return true
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_out()
			_count("key_out")
			_ping("key")
			return true
		KEY_0, KEY_KP_0:
			reset()
			_ping("key_reset")
			return true
	return false


func _toggle_zoom() -> void:
	## Normal <-> Dekat (double tap). Bila sedang di posisi lain (mis. terjauh)
	## → kembali ke Normal (Material: "double-touch at maximum zoom" = zoom out).
	if absf(_zoom - ZOOM_DEFAULT) < 0.12:
		set_zoom_raw(CLOSE_LEVEL)
	else:
		set_zoom_raw(ZOOM_DEFAULT)


func _pan_by_screen(delta: Vector2) -> void:
	## Konten mengikuti jari: fokus bergerak berlawanan arah geser layar.
	## Skala world-per-pixel di bidang fokus (≈ proyeksi kamera).
	if camera == null or delta == Vector2.ZERO:
		return
	var vp := get_viewport()
	var h := float(vp.get_visible_rect().size.y) if vp != null else 720.0
	h = maxf(1.0, h / maxf(0.01, scale_of_hud()))
	var k := 2.0 * (_base_dist * _zoom) * tan(deg_to_rad(camera.fov * 0.5)) / h
	var right := camera.global_transform.basis.x
	var up_screen := -camera.global_transform.basis.z
	var right_xz := Vector3(right.x, 0.0, right.z)
	var up_xz := Vector3(up_screen.x, 0.0, up_screen.z)
	if right_xz.length() < 0.001:
		right_xz = Vector3.RIGHT
	if up_xz.length() < 0.001:
		up_xz = Vector3.FORWARD
	right_xz = right_xz.normalized()
	up_xz = up_xz.normalized()
	var move := (-right_xz * delta.x + up_xz * delta.y) * k
	set_pan_raw(_pan + Vector2(move.x, move.z))


func scale_of_hud() -> float:
	## HUD/3D tidak di-scale (root viewport adaptif) → 1. Dibuat fungsi supaya
	## kalau nanti ada skala, perhitungan px konsisten (bukan asumsi di 3 tempat).
	return 1.0


# ------------------------------------------------------------------ apply ---
func apply(delta: float) -> void:
	if camera == null:
		return
	var t := 1.0 - exp(-SMOOTH * maxf(0.0, delta))
	_zoom_cur = lerpf(_zoom_cur, _zoom, t)
	_pan_cur = _pan_cur.lerp(_pan, t)
	if absf(_zoom_cur - _zoom) < 0.0005:
		_zoom_cur = _zoom
	if _pan_cur.distance_to(_pan) < 0.01:
		_pan_cur = _pan
	var focus := _focus_base + Vector3(_pan_cur.x, 0.0, _pan_cur.y)
	var dist := _base_dist * _zoom_cur
	var pos := focus + _view_dir * dist
	pos.y = maxf(CAM_MIN_Y, pos.y)
	camera.global_position = pos
	camera.look_at(focus, Vector3.UP)
	_dirty = false
	_emit(false)


func apply_now() -> void:
	## Terapkan tanpa smoothing (test/snapshot foto).
	_zoom_cur = _zoom
	_pan_cur = _pan
	apply(0.0)


func _emit(force: bool) -> void:
	## Marker + sinyal ke HUD, dibatasi 10 Hz supaya pinch tidak membanjiri log
	## (log dipakai gate: marker harus mencerminkan state nyata, bukan spam).
	var now := Time.get_ticks_msec() / 1000.0
	var cur := Vector3(_zoom, _pan.x, _pan.y)
	if not force:
		if cur.distance_to(_last_emit) < 0.002:
			return  ## state tidak berubah → jangan spam log gate
		if now - _emit_t < 0.1:
			return
	_emit_t = now
	_last_emit = cur
	EventBus.camera_changed.emit(scale(), _pan)
	QaMarkers.marker("CAM", "STATE", state())


func _ping(kind: String) -> void:
	QaMarkers.marker("CAM", "GESTURE", {"kind": kind, "scale": snappedf(scale(), 0.01),
		"zoom": snappedf(_zoom, 0.001)})
