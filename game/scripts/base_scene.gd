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


func _ready() -> void:
	## M3.5: kamera sedikit naik + tilt landai supaya langit (bintang/planet)
	## masuk FOV — arena space terlihat, bukan hanya platform.
	camera.position = Vector3(0, 20, 30)
	camera.look_at(Vector3(0, 3, -8), Vector3.UP)
	camera.fov = 82  ## langit lebih luas masuk FOV (bintang/bulan/planet)
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
	planet.position = Vector3(80, 32, -105)  ## depan kamera (kamera hadap -Z)
	add_child(planet)
	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	moon.mesh = _big_sphere(8.0, Color(0.5, 0.46, 0.4))
	moon.position = Vector3(48, 42, -72)
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
	QaMarkers.marker("SCENE", "ENV", {"stars": 350, "planet": 1, "asteroids": 7})


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
