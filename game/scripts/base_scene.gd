extends Node3D
## BaseScene — scene utama (Command Mode): kamera, base, sistem, HUD.
## Menempatkan Command Core saat game baru (idempotent — skip jika sudah ada,
## misal setelah load).
##
## M3 #1: klik bangunan di arena 3D → indikator panah hijau + selection panel
## (HUD.select_building, pola Doomsday F4 — GAMEPLAY_FLOW.md §0/§3).
## Pick pakai proyeksi kamera (unproject) + nearest — tanpa physics server,
## robust di build WASM dan deterministik untuk test.

@onready var camera: Camera3D = $Camera3D
@onready var hud: Control = $HUD/HUDControl

const PICK_RADIUS_PX := 96.0  ## radius pick 96px @1280 lebar (~7,5% lebar layar)

var _arrow: MeshInstance3D
var _arrow_target: String = ""
var _bob_t := 0.0
var _declutter_t := 0.0
var _label_db := ""  ## tanda tangan QA label (hindari spam log)


func _ready() -> void:
	## M3.5: kamera sedikit naik + tilt landai supaya langit (bintang/planet)
	## masuk FOV — arena space terlihat, bukan hanya platform.
	## M3.7: kamera didekatkan DAN menghadap sisi tempat pangkalan tumbuh.
	## Fakta terukur: BuildingSystem menempatkan bangunan mulai HQ (0,0,0) lalu
	## bertambah ke +x/+z (next_free_position), jadi pangkalan ada di sumbu +z —
	## kamera harus di -z menghadap +z, kalau tidak bangunan baru muncul di
	## BELAKANG kamera (temuan foto: "canvas 3D masih prototype", hanya HQ terlihat).
	camera.position = Vector3(0, 15, -21)
	camera.look_at(Vector3(0, 2.6, 6), Vector3.UP)
	camera.fov = 74
	_create_environment()  ## M3.5: arena space (sky, bintang, planet, platform grid)
	var bs: BuildingSystem = $BuildingSystem
	if bs.count_of(&"command_core") == 0:
		bs.place_building(&"command_core", Vector3(0, 0, 0))
	_create_arrow()
	EventBus.building_destroyed.connect(_on_building_destroyed)
	QaMarkers.marker("SCENE", "READY", {})


func reduce_environment_for_benchmark() -> void:
	## M3.5: untuk stress/perf scene — hapus dekorasi berat (bintang, planet,
	## bulan, asteroid, grid emissive), sisakan sky + platform polos.
	## Benchmark mengukur gameplay (42 kapal + 8 turret), bukan dekorasi;
	## tanpa ini SwiftShader terlalu lambat (sampling tidak selesai < 180s).
	for n in ["Stars", "Planet", "Moon"]:
		var c := get_node_or_null(n)
		if c != null:
			c.queue_free()
	for i in range(7):
		var a := get_node_or_null("Asteroid_%d" % i)
		if a != null:
			a.queue_free()
	for extra in ["PlatformRim", "Pylons", "LandingPads", "KeyLight", "ArenaProps"]:
		var e := get_node_or_null(extra)
		if e != null:
			e.queue_free()
	var ground: MeshInstance3D = $Ground
	if ground != null and ground.mesh != null:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(0.055, 0.07, 0.13)
		ground.mesh.material = plain


# ------------------------------------------------------- environment ----
func _create_environment() -> void:
	## Arena space: sky gelap + bintang + planet + platform grid emissive +
	## asteroid. Semua visual dari kode (tidak butuh aset eksternal).
	# --- sky: WorldEnvironment (dark space + ambient) ---
	var env := WorldEnvironment.new()
	env.name = "SpaceEnv"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.02, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.16, 0.19, 0.28)
	environment.ambient_light_energy = 0.5
	env.environment = environment
	add_child(env)

	# --- bintang: MultiMesh (ratusan bola kecil putih di langit, 1 node) ---
	# Catatan: CPUParticles3D tidak ter-render di SwiftShader (verifikasi foto),
	# maka bintang = instance mesh seeded (pasti tampil, tetap deterministik).
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.25
	star_mesh.height = 0.5
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.92, 0.95, 1.0)
	star_mesh.material = smat
	var mm := MultiMeshInstance3D.new()
	mm.name = "Stars"
	var multi := MultiMesh.new()
	multi.mesh = star_mesh
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = 300
	for i in range(300):
		var sx := (SeededRng.next_float() * 2.0 - 1.0) * 130.0
		var sy := 35.0 + SeededRng.next_float() * 60.0
		var sz := (SeededRng.next_float() * 2.0 - 1.0) * 130.0
		var sr := 0.5 + SeededRng.next_float() * 1.2
		multi.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(sr, sr, sr)), Vector3(sx, sy, sz)))
	mm.multimesh = multi
	add_child(mm)

	# --- planet besar di kejauhan (kanan belakang kamera) + bulan ---
	var planet := MeshInstance3D.new()
	planet.name = "Planet"
	planet.mesh = _big_sphere(22.0, Color(0.13, 0.28, 0.55))
	planet.position = Vector3(46, 24, 112)  ## langit atas-kanan (kamera hadap +Z, tilt -19°)
	add_child(planet)
	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	moon.mesh = _big_sphere(8.0, Color(0.5, 0.46, 0.4))
	moon.position = Vector3(24, 33, 82)
	add_child(moon)

	# --- platform: box solid + grid emissive (ganti ground plane polos) ---
	var ground: MeshInstance3D = $Ground
	var box := BoxMesh.new()
	box.size = Vector3(80, 0.5, 80)
	ground.mesh = box
	ground.position = Vector3(0, -0.25, 0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.055, 0.07, 0.13)
	gmat.metallic = 0.2
	gmat.roughness = 0.8
	gmat.emission_enabled = true
	gmat.emission_texture = _grid_texture()
	gmat.emission_energy_multiplier = 0.7
	gmat.uv1_scale = Vector3(10, 10, 1)  ## grid 8m × 8m
	ground.mesh.material = gmat

	# --- asteroid kecil di pinggir platform (seeded → deterministik) ---
	for i in range(7):
		var ast := MeshInstance3D.new()
		ast.name = "Asteroid_%d" % i
		var r := 1.5 + SeededRng.next_float() * 2.0
		ast.mesh = _big_sphere(r, Color(0.32 + SeededRng.next_float() * 0.1, 0.3, 0.27))
		var ang := SeededRng.next_float() * TAU
		var dist := 30.0 + SeededRng.next_float() * 8.0
		ast.position = Vector3(cos(ang) * dist, 0.4 + r * 0.5, sin(ang) * dist)
		ast.rotation = Vector3(SeededRng.next_float() * TAU, SeededRng.next_float() * TAU, 0)
		add_child(ast)
	# --- pencahayaan utama (arah cahaya matahari jauh) + rim arena ---
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(0.82, 0.88, 1.0)
	key.light_energy = 0.85
	key.rotation_degrees = Vector3(-52, -34, 0)
	key.shadow_enabled = false  ## bayangan mahal di web/SwiftShader (dilaporkan QA)
	add_child(key)

	_create_platform_rim()
	_create_landing_pads()
	_create_arena_props()

	QaMarkers.marker("SCENE", "ENV", {"stars": 350, "planet": 1, "asteroids": 7,
		"rim": 4, "pylons": 4, "pads": 2})


func _create_platform_rim() -> void:
	## Tepi platform emissive + pylon sudut: arena terbaca sebagai PLATFORM
	## (bukan bidang tak berujung) — perbaikan "canvas 3D masih prototype".
	var rim := Node3D.new()
	rim.name = "PlatformRim"
	add_child(rim)
	var edge := 80.0
	for i in range(4):
		var along := Vector3(edge, 0.16, 0.5) if i % 2 == 0 else Vector3(0.5, 0.16, edge)
		var mi := MeshInstance3D.new()
		mi.name = "Rim_%d" % i
		var bm := BoxMesh.new()
		bm.size = along
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.13, 0.5, 0.75)
		mat.emission_enabled = true
		mat.emission = Color(0.208, 0.816, 1.0)
		mat.emission_energy_multiplier = 1.6
		bm.material = mat
		mi.mesh = bm
		mi.position = Vector3(
			(0.0 if i % 2 == 0 else (-edge / 2.0 if i == 1 else edge / 2.0)),
			0.06,
			(0.0 if i % 2 == 0 else (-edge / 2.0 if i == 1 else edge / 2.0)))
		if i % 2 == 0:
			mi.position.z = -edge / 2.0 if i == 0 else edge / 2.0
		rim.add_child(mi)
	var pylons := Node3D.new()
	pylons.name = "Pylons"
	add_child(pylons)
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + PI / 4.0
		var px := cos(ang) * edge * 0.48
		var pz := sin(ang) * edge * 0.48
		var post := MeshInstance3D.new()
		post.name = "Pylon_%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = 0.35
		cm.bottom_radius = 0.55
		cm.height = 6.0
		cm.radial_segments = 8
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.22, 0.26, 0.34)
		pmat.metallic = 0.4
		cm.material = pmat
		post.mesh = cm
		post.position = Vector3(px, 3.0, pz)
		pylons.add_child(post)
		var lamp := MeshInstance3D.new()
		lamp.name = "PylonLamp_%d" % i
		var lm := SphereMesh.new()
		lm.radius = 0.45
		lm.height = 0.9
		var lmat := StandardMaterial3D.new()
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lmat.albedo_color = Color(0.9, 0.95, 1.0)
		lm.material = lmat
		lamp.mesh = lm
		lamp.position = Vector3(px, 6.3, pz)
		pylons.add_child(lamp)


func _create_arena_props() -> void:
	## Properti arena (deterministik): kontainer kargo + batu + tiang kom —
	## mengisi bidang kosong supaya terbaca sebagai pangkalan, bukan prototype.
	var props := Node3D.new()
	props.name = "ArenaProps"
	add_child(props)
	var mat_box := StandardMaterial3D.new()
	mat_box.albedo_color = Color(0.30, 0.33, 0.38)
	mat_box.metallic = 0.3
	mat_box.roughness = 0.7
	var mat_rock := StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.26, 0.25, 0.24)
	mat_rock.roughness = 0.95
	# kontainer kargo (2 tumpuk × 3)
	for i in range(6):
		var bx := MeshInstance3D.new()
		bx.name = "Cargo_%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(1.8, 1.1, 1.1)
		var c: Color = [Color(0.55, 0.42, 0.22), Color(0.25, 0.4, 0.5), Color(0.45, 0.3, 0.3)][i % 3]
		var m := mat_box.duplicate()
		m.albedo_color = c
		bm.material = m
		bx.mesh = bm
		var col := float(i % 3) * 2.0 - 2.0
		bx.position = Vector3(-17.0 + col * 0.4, 0.55 + float(i / 3) * 1.15, -9.0 - float(i / 3) * 1.3)
		bx.rotation_degrees = Vector3(0, 12.0 * float(i % 3) - 12.0, 0)
		props.add_child(bx)
	# batu (sphere dipipihkan, seeded)
	for i in range(5):
		var rk := MeshInstance3D.new()
		rk.name = "Rock_%d" % i
		var sm := SphereMesh.new()
		var r := 0.9 + SeededRng.next_float() * 1.1
		sm.radius = r
		sm.height = r * 0.75          ## pipih (bukan bola mengapung)
		sm.material = mat_rock
		rk.mesh = sm
		var ang := SeededRng.next_float() * TAU
		var d := 27.0 + SeededRng.next_float() * 6.0
		## diletakkan di pinggir luar area bangunan (bukan di tengah pad)
		rk.position = Vector3(cos(ang) * d, r * 0.22, sin(ang) * d - 6.0)
		rk.rotation = Vector3(SeededRng.next_float(), SeededRng.next_float() * TAU, 0)
		props.add_child(rk)
	# tiang komunikasi (di luar grid bangunan)
	for i in range(2):
		var mast := Node3D.new()
		mast.name = "CommMast_%d" % i
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.2
		cm.height = 7.0
		cm.material = mat_box
		pole.mesh = cm
		pole.position = Vector3(0, 3.5, 0)
		mast.add_child(pole)
		var dish := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.7
		dm.height = 0.5
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.75, 0.78, 0.82)
		dmat.metallic = 0.2
		dm.material = dmat
		dish.mesh = dm
		dish.position = Vector3(0, 7.1, 0)
		mast.add_child(dish)
		mast.position = Vector3(-33.0 if i == 0 else 33.0, 0, -9.0 if i == 0 else -4.0)
		props.add_child(mast)


func _create_landing_pads() -> void:
	## Dua pad landasan (cincin emissive + tengah gelap) — menandai area
	## operasi di arena supaya bidang tidak terasa kosong.
	var pads := Node3D.new()
	pads.name = "LandingPads"
	add_child(pads)
	## Di LUAR area grid bangunan (x 0..46 × z 0..46 — posisi tumbuh dari HQ),
	## supaya tidak tertimpa bangunan yang dibangun pemain.
	var spots := [Vector3(-25, 0.06, -5), Vector3(27, 0.06, -7)]
	for i in range(spots.size()):
		var pad := MeshInstance3D.new()
		pad.name = "Pad_%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = 7.0
		cm.bottom_radius = 7.0
		cm.height = 0.12
		cm.radial_segments = 24
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.07, 0.09, 0.16)
		mat.emission_enabled = true
		mat.emission = Color(0.208, 0.816, 1.0)
		mat.emission_energy_multiplier = 0.28
		cm.material = mat
		pad.mesh = cm
		pad.position = spots[i]
		pads.add_child(pad)
		var ring := MeshInstance3D.new()
		ring.name = "PadRing_%d" % i
		var tm := TorusMesh.new()
		tm.inner_radius = 6.1
		tm.outer_radius = 6.5
		tm.rings = 32
		tm.ring_segments = 6
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.208, 0.816, 1.0)
		rmat.emission_enabled = true
		rmat.emission = Color(0.208, 0.816, 1.0)
		rmat.emission_energy_multiplier = 1.5
		tm.material = rmat
		ring.mesh = tm
		ring.position = spots[i] + Vector3(0, 0.08, 0)
		pads.add_child(ring)


func _tiny_sphere(radius: float, color: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material = mat
	return m


func _big_sphere(radius: float, color: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	m.material = mat
	return m


func _grid_texture() -> ImageTexture:
	## Generate grid emissive texture saat runtime (garis cyan di atas
	## transparan — hanya garis yang glow, tidak butuh aset eksternal).
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var line := Color(0.208, 0.816, 1.0, 0.85)  ## cyan hologram
	for i in range(0, 256, 64):
		for x in range(256):
			img.set_pixel(x, i, line)
			img.set_pixel(i, x, line)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------ arrow ----
func _create_arrow() -> void:
	## Panah hijau di atas bangunan terpilih (indikator, pola Doomsday F4).
	_arrow = MeshInstance3D.new()
	_arrow.name = "SelectionArrow"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.9, 1.4, 0.9)
	_arrow.mesh = prism
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 1.0, 0.53)
	mat.emission_enabled = true
	mat.emission = Color(0.30, 1.0, 0.53)
	mat.emission_energy_multiplier = 1.5
	_arrow.mesh.material = mat
	_arrow.rotation_degrees = Vector3(180, 0, 0)  ## prisma default apex +Y → ke bawah
	_arrow.visible = false
	add_child(_arrow)


func _process(delta: float) -> void:
	## 20 Hz: jendela waktu saat label baru dibangun tampil-belum-terdeclutter
	## turun ke ≤50 ms (temuan foto e2e: label baru masih bisa tampil berdempet).
	_declutter_t += delta
	if _declutter_t >= 0.05:
		_declutter_t = 0.0
		_declutter_labels()
	if not _arrow.visible or _arrow_target == "":
		return
	var bs: BuildingSystem = $BuildingSystem
	var b := bs.get_building(_arrow_target)
	if b == null or b.is_destroyed():
		deselect()
		return
	_bob_t += delta
	## tinggi bangunan dari footprint (placeholder visual 1.5×footprint, y/2)
	var h := maxf(1.0, float(b.def.footprint.y)) * 1.5
	_arrow.position = b.position + Vector3(0, h / 2.0 + 1.2 + sin(_bob_t * 3.0) * 0.15, 0)
	_arrow.rotation_degrees = Vector3(180, _bob_t * 60.0, 0)  ## spin pelan


# ---------------------------------------------------------- label 3D ----
func _declutter_labels() -> void:
	## ANTI-TUMPUK teks di canvas 3D: label dunia yang kotaknya beririsan di
	## ruang layar disembunyikan (prioritas: bangunan terpilih, lalu terdekat
	## kamera). Setelah penempatan, jumlah irisan DIUKUR ULANG (bukan asumsi)
	## dan dilaporkan sebagai marker QA:SCENE:LABEL_OVERLAP — verifikasi terukur.
	var bs: BuildingSystem = $BuildingSystem
	if bs == null:
		return
	var entries: Array = []
	for b in bs.get_all_buildings():
		if b.is_destroyed() or not b.visible:
			b.set_label_visible(false)  ## reruntuhan/pending tidak berlabel
			continue
		var wp: Vector3 = b.label_anchor()
		if not camera.is_position_in_frustum(wp):
			b.set_label_visible(false)
			continue
		var sp: Vector2 = camera.unproject_position(wp)
		var ext: Vector2 = b.label_extent_px()
		entries.append({
			"b": b,
			"sp": sp,
			"rect": Rect2(sp - ext * 0.5, ext),
			"d": camera.global_position.distance_to(wp),
			"sel": b.instance_id == _arrow_target,
		})
	entries.sort_custom(func(a, c):
		if a["sel"] != c["sel"]:
			return a["sel"]  ## yang terpilih selalu menang
		return a["d"] < c["d"])
	var placed: Array = []
	for e in entries:
		var r: Rect2 = e["rect"]
		var clash := false
		for p in placed:
			if r.intersects(p):
				clash = true
				break
		(e["b"] as Building).set_label_visible(not clash)
		if not clash:
			placed.append(r)
	## ukur ulang irisan antar label yang BENAR-BENAR terlihat
	var overlap := 0
	for i in range(placed.size()):
		for j in range(i + 1, placed.size()):
			if (placed[i] as Rect2).intersects(placed[j]):
				overlap += 1
	var sig := "%d/%d/%d/%d" % [placed.size(), entries.size() - placed.size(), entries.size(), overlap]
	if sig != _label_db:  ## hanya saat berubah (hindari spam log)
		_label_db = sig
		print("QA:SCENE:LABEL_OVERLAP count=%d visible=%d hidden=%d total=%d" % [
			overlap, placed.size(), entries.size() - placed.size(), entries.size()])
		for e in entries:
			print("QA:SCENE:LABEL_DBG text=%s at=(%d,%d) vis=%s" % [
				e["b"].label_text(), int((e["sp"] as Vector2).x), int((e["sp"] as Vector2).y),
				str(e["b"].label_visible())])


# ------------------------------------------------------------- pick ----
func _unhandled_input(event: InputEvent) -> void:
	if hud != null and (hud.is_build_menu_open() or hud.is_ship_menu_open() or hud.is_pause_menu_open()):
		return  ## modal terbuka — jangan pick
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_pick(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pick(st.position)


func _pick(screen_pos: Vector2) -> void:
	## Proyeksi semua bangunan ke layar, pilih terdekat dalam radius pick.
	var bs: BuildingSystem = $BuildingSystem
	var best: Building = null
	var best_d := PICK_RADIUS_PX
	for b in bs.get_all_buildings():
		if b.is_destroyed():
			continue
		var sp := camera.unproject_position(b.global_position + Vector3(0, 1.0, 0))
		var d := sp.distance_to(screen_pos)
		if d <= best_d:
			best_d = d
			best = b
	if best != null:
		select_building(best)
	else:
		deselect()


func select_building(b: Building) -> void:
	_arrow_target = b.instance_id
	_arrow.visible = true
	_bob_t = 0.0
	if hud != null:
		hud.select_building(b.instance_id)


func deselect() -> void:
	_arrow_target = ""
	_arrow.visible = false
	if hud != null:
		hud.deselect_building()


func get_arrow_target() -> String:
	return _arrow_target


func _on_building_destroyed(instance_id: String) -> void:
	if instance_id == _arrow_target:
		deselect()
