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
var rig: CameraRig                      ## M3 #6: zoom + pan Command Mode
@onready var hud: Control = $HUD/HUDControl

const PICK_RADIUS_PX := 96.0  ## radius pick 96px @1280 lebar (~7,5% lebar layar)
## Ukuran plataran arena (M3 #8): satu sumber untuk ground, rim, dan BATAS
## KAMERA. 80×80 unit; kamera dibatasi 38 unit dari pusat (= tepi 40 − margin 2)
## supaya pandangan tidak pernah melewati tepi daratan (logika base-builder).
const ARENA_SIZE := 80.0
const ARENA_HALF := ARENA_SIZE * 0.5
const CAMERA_HALF := ARENA_HALF - 2.0

var _arrow: MeshInstance3D
var _arrow_target: String = ""
var _bob_t := 0.0
var _declutter_t := 0.0
var _label_db := ""  ## tanda tangan QA label (hindari spam log)
var _arena_png_count := 0  ## jumlah elemen arena yang benar-benar dari PNG (M3 #7)
var _label_menu_state := ""  ## M3 #4: "" → belum, "hidden"/"world" (marker QA)
# --- M3 #4: kamera idle saat menu utama (zoom/pan halus, bukan kamera statis) ---
var _cam_base_pos := Vector3.ZERO
var _cam_focus := Vector3.ZERO
var _menu_t := 0.0
var _menu_idle := false


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
	## M3 #9: sudut kamera Command Mode dinaikkan & difokuskan ke TENGAH plataran
	## → seluruh benteng (dinding + bastion + inti + ring produksi) terbaca
	## sekaligus tanpa harus zoom-out sampai bangunan jadi kecil.
	## sedikit menyamping (3/4) supaya DUA sisi dinding + bastion + gerbang
	## terbaca bersamaan (kamera lurus hanya memperlihatkan satu sisi benteng).
	camera.position = Vector3(13.0, 20.5, -25.0)
	_cam_base_pos = camera.position
	_cam_focus = Vector3(0, 0.0, 4.0)
	## M3 #6: kamera dikendalikan CameraRig (zoom/pan) — kamera tetap node scene.
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(camera, _cam_base_pos, _cam_focus)
	## M3 #8: batas kamera dari UKURAN ARENA NYATA (bukan radius tetap) + hitung
	## ulang saat layar berubah ukuran/orientasi (zoom "seluruh basis" dihitung
	## dari geometri: fov + aspek + ukuran arena).
	rig.configure_arena(Vector3(0, 0, 0), Vector2(CAMERA_HALF, CAMERA_HALF))
	## M3 #9: tombol zoom-out tetap bisa mencapai "seluruh benteng" (zoom_far
	## dihitung geometris di rig); default TETAP 1,0× supaya bangunan besar.
	get_viewport().size_changed.connect(_on_viewport_resized_camera)
	EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested)
	EventBus.camera_reset_requested.connect(_on_camera_reset_requested)
	_create_environment()  ## M3.5: arena space (sky, bintang, planet, platform grid)
	var bs: BuildingSystem = $BuildingSystem
	if bs.count_of(&"command_core") == 0:
		## M3 #9: basis awal = RENCANA TATA LETAK (inti tengah, produksi ring-1,
		## pertahanan ring-2) — bukan satu bangunan di tengah + sisanya acak.
		bs.apply_layout_plan()
		var cov := bs.core_covered_by_defense()
		print("QA:BUILD:COVERAGE %s" % str(cov))
	EventBus.placement_requested.connect(_on_placement_requested)
	_create_arrow()
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.main_menu_requested.connect(_on_main_menu_requested)
	var mm: Control = hud.get_main_menu()
	if mm != null:
		mm.connect("play_requested", _on_main_menu_play)
	_sync_menu_state()  ## boot bisa langsung di fase MENU (M3 #4)
	QaMarkers.marker("SCENE", "READY", {})


# ------------------------------------------------- menu utama (M3 #4) ----
func _sync_menu_state() -> void:
	## Fase MENU = base idle: waktu beku (tidak ada wave/produksi berjalan saat
	## pemain masih di menu), kamera idle, chrome HUD disembunyikan.
	if GameManager.phase == GameManager.Phase.MENU:
		TimeSystem.pause()
		_menu_idle = true
		hud.open_main_menu()
		QaMarkers.marker("MENU", "SCENE", {"state": "boot_menu", "speed": TimeSystem.speed})


func _on_main_menu_requested() -> void:
	## Dipicu pause menu (Frame 8 → Frame 3): simpan sudah dilakukan pemanggil.
	show_main_menu(true)


## Tampilkan menu utama di atas base 3D yang idle (waktu beku).
##   session=true  → lanjutan sesi berjalan ("LANJUTKAN PERMAINAN")
##   session=false → menu dingin; tombol utama dari save di disk ("LANJUTKAN")
func show_main_menu(session: bool) -> void:
	if GameManager.phase != GameManager.Phase.MENU:
		GameManager.return_to_menu()  ## menu tampil ⇔ fase MENU
	TimeSystem.pause()
	_menu_idle = true
	_menu_t = 0.0
	var mm: Control = hud.get_main_menu()
	if mm != null:
		mm.call("set_session_active", session)
	hud.open_main_menu()
	QaMarkers.marker("MENU", "SCENE", {"state": "open", "session": session,
		"speed": TimeSystem.speed})


func _on_main_menu_play(_action: String) -> void:
	TimeSystem.resume()
	_menu_idle = false
	## M3 #6: kamera kembali ke tampilan kanonik Command Mode lewat rig
	## (zoom 1,0 / pan 0) — bukan set posisi langsung (dua sumber akan bertengkar).
	rig.reset()
	rig.apply_now()
	var mm: Control = hud.get_main_menu()
	if mm != null:
		mm.call("set_session_active", true)
	QaMarkers.marker("MENU", "SCENE", {"state": "playing", "speed": TimeSystem.speed,
		"phase": GameManager.get_phase_name()})


func reduce_environment_for_benchmark() -> void:
	## M3.5: untuk stress/perf scene — hapus dekorasi berat (bintang, planet,
	## bulan, asteroid, grid emissive), sisakan sky + platform polos.
	## Benchmark mengukur gameplay (42 kapal + 8 turret), bukan dekorasi;
	## tanpa ini SwiftShader terlalu lambat (sampling tidak selesai < 180s).
	for n in ["Stars", "Planet", "Moon", "Nebula", "Station"]:
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
## Elemen arena dari PNG (chroma-key). Mengembalikan node atau null bila gagal.
func _add_arena_sprite(node_name: String, tex_id: String, pos: Vector3, world_w: float) -> Node:
	var tex := _load_arena_texture(tex_id)
	if tex == null:
		print("QA:ARENA:PNG id=%s src=none (PNG tidak bisa dimuat — fallback mesh)" % tex_id)
		return null
	var sp := Sprite3D.new()
	sp.name = node_name
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED  ## selalu menghadap kamera
	sp.pixel_size = world_w / float(tex.get_width())
	sp.position = pos
	sp.no_depth_test = false
	add_child(sp)
	print("QA:ARENA:PNG id=%s src=png size=%dx%d world=%.1f pos=%s" % [
		tex_id, tex.get_width(), tex.get_height(), world_w, str(pos)])
	_arena_png_count += 1
	return sp


func _load_arena_texture(tex_id: String) -> Texture2D:
	## PNG mentah dari pck (tanpa importer Godot) → ImageLoader engine.
	var img := Image.load_from_file("res://assets/arena/%s.png" % tex_id)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


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
	environment.ambient_light_color = Color(0.22, 0.26, 0.36)
	environment.ambient_light_energy = 0.85
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

	# --- elemen arena dari FOTO PNG (chroma-key) — permintaan pemain 2026-10-13:
	#     "untuk arena itu elementnya juga pakai png, kamu generate foto dengan
	#     chromase seperti planet dll". Aset: assets/arena/*.png (dipotong
	#     tools/art/chroma_key.py dari foto ber-latar magenta). Bila PNG gagal
	#     dimuat, mesh kode lama dipakai dan sumbernya DILAPORKAN (marker
	#     QA:ARENA:PNG) — bukan disembunyikan.
	var planet := _add_arena_sprite("Planet", "planet_gas_ringed", Vector3(46, 26, 112), 46.0)
	if planet == null:
		planet = MeshInstance3D.new()
		planet.name = "Planet"
		(planet as MeshInstance3D).mesh = _big_sphere(22.0, Color(0.13, 0.28, 0.55))
		planet.position = Vector3(46, 24, 112)
		add_child(planet)
	var moon := _add_arena_sprite("Moon", "moon_rocky", Vector3(24, 33, 82), 18.0)
	if moon == null:
		moon = MeshInstance3D.new()
		moon.name = "Moon"
		(moon as MeshInstance3D).mesh = _big_sphere(8.0, Color(0.5, 0.46, 0.4))
		moon.position = Vector3(24, 33, 82)
		add_child(moon)
	## Nebula + stasiun orbit: elemen latar tambahan (PNG, billboard).
	_add_arena_sprite("Nebula", "nebula_cluster", Vector3(-68, 34, 150), 90.0)
	_add_arena_sprite("Station", "station_orbital", Vector3(-46, 9, 58), 26.0)

	# --- platform: box solid + grid emissive (ganti ground plane polos) ---
	var ground: MeshInstance3D = $Ground
	var box := BoxMesh.new()
	box.size = Vector3(ARENA_SIZE, 0.5, ARENA_SIZE)
	ground.mesh = box
	ground.position = Vector3(0, -0.25, 0)
	var gmat := StandardMaterial3D.new()
	## M3 #9: permukaan plataran = FOTO PNG (deck_fortress) yang di-chroma-key /
	## di-tile, bukan warna+garis dari kode. Grid emissive lama DIHAPUS: garis
	## grid sekarang bagian dari tekstur deck (pola pelat berpanel).
	var deck := _load_arena_texture("deck_fortress")
	if deck != null:
		gmat.albedo_texture = deck
		gmat.albedo_color = Color(1, 1, 1)
		gmat.metallic = 0.25
		gmat.roughness = 0.72
		## 1 ubin gambar ≈ 16 unit dunia (pelat besar) → 80/16 = 5.
		gmat.uv1_scale = Vector3(5, 5, 1)
		print("QA:ARENA:DECK src=png size=%dx%d tile=16" % [deck.get_width(), deck.get_height()])
	else:
		gmat.albedo_color = Color(0.055, 0.07, 0.13)
		gmat.metallic = 0.2
		gmat.roughness = 0.8
		gmat.emission_enabled = true
		gmat.emission_texture = _grid_texture()
		gmat.emission_energy_multiplier = 0.7
		gmat.uv1_scale = Vector3(10, 10, 1)
		print("QA:ARENA:DECK src=procedural (PNG gagal dimuat)")
	ground.mesh.material = gmat

	# --- asteroid kecil di pinggir platform (seeded → deterministik) ---
	for i in range(7):
		var ast := MeshInstance3D.new()
		ast.name = "Asteroid_%d" % i
		var r := 1.5 + SeededRng.next_float() * 2.0
		ast.mesh = _big_sphere(r, Color(0.32 + SeededRng.next_float() * 0.1, 0.3, 0.27))
		var ang := SeededRng.next_float() * TAU
		## M3 #9: asteroid = batuan DI LUAR dinding benteng (52–62 unit; dinding di
		## ±40) — sebelumnya 30–38 (di DALAM plataran) sehingga menutupi arena.
		var dist := 52.0 + SeededRng.next_float() * 10.0
		ast.position = Vector3(cos(ang) * dist, -1.5 - r * 0.4, sin(ang) * dist)
		ast.rotation = Vector3(SeededRng.next_float() * TAU, SeededRng.next_float() * TAU, 0)
		add_child(ast)
	# --- pencahayaan utama (arah cahaya matahari jauh) + rim arena ---
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(0.86, 0.91, 1.0)
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-52, -34, 0)
	key.shadow_enabled = false  ## bayangan mahal di web/SwiftShader (dilaporkan QA)
	## Fill light dari arah berlawanan (M3 #9): memisahkan sisi gelap bangunan
	## dari dek gelap — tanpa ini model hanya terbaca siluet. Murah, tanpa shadow.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.55, 0.72, 1.0)
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-18, 138, 0)
	fill.shadow_enabled = false
	add_child(fill)
	add_child(key)

	_create_platform_rim()
	_create_fortress()      ## M3 #9: dinding benteng PNG + bastion + gerbang
	_create_landing_pads()
	_create_arena_props()

	## Marker memuat NILAI NYATA: bintang 300 (multi.instance_count=300 di atas),
	## marker lama menulis 350 → angka marker ≠ state (temuan QA, diperbaiki).
	QaMarkers.marker("SCENE", "ENV", {"stars": 300, "planet": 1, "asteroids": 7,
		"rim": 4, "pylons": 4, "pads": 2})


func _create_fortress() -> void:
	## M3 #9 — markas luar angkasa BERPENTENG (permintaan pemain 2026-10-14:
	## "game arena nya harusnya dibuat seperti di dalam markas luar angkasa punya
	## benteng"). Semua permukaan = TEKSTUR PNG hasil foto (rampart_wall),
	## bukan warna/material dari kode. Bentuk: 4 sisi dinding berlapis dengan
	## GERBANG di tengah tiap sisi + bastion di 4 sudut (pola benteng bintang).
	var root := Node3D.new()
	root.name = "Fortress"
	add_child(root)
	var tex := _load_arena_texture("rampart_wall")
	if tex == null:
		print("QA:ARENA:FORTRESS src=none (rampart_wall.png gagal dimuat — dilewati)")
		return
	var wall_h := 3.0
	var wall_t := 1.2
	var gate_w := 12.0
	var half := ARENA_HALF + wall_t * 0.5
	var seg := (ARENA_SIZE - gate_w) * 0.5      ## panjang tiap segmen dinding
	var wall_count := 0
	for side in range(4):
		for sgn in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.name = "Wall_%d_%s" % [side, "L" if sgn < 0 else "R"]
			var bm := BoxMesh.new()
			var horizontal := side % 2 == 0
			bm.size = Vector3(seg, wall_h, wall_t) if horizontal else Vector3(wall_t, wall_h, seg)
			mi.mesh = bm
			var offset: float = (gate_w * 0.5 + seg * 0.5) * sgn
			if horizontal:
				mi.position = Vector3(offset, wall_h * 0.5, (1.0 if side == 0 else -1.0) * half)
			else:
				mi.position = Vector3((1.0 if side == 1 else -1.0) * half, wall_h * 0.5, offset)
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex
			m.uv1_scale = Vector3(maxf(1.0, seg / 12.0), 1.0, 1.0)  ## ubin ≈12 unit
			m.metallic = 0.35
			m.roughness = 0.55
			mi.mesh.material = m
			root.add_child(mi)
			wall_count += 1
	## bastion 4 sudut (lebih tinggi dari dinding → silhuet benteng terbaca)
	var bastion_count := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bs := MeshInstance3D.new()
			bs.name = "Bastion_%s_%s" % ["W" if sx < 0 else "E", "N" if sz < 0 else "S"]
			var bb := BoxMesh.new()
			bb.size = Vector3(9, wall_h + 2.6, 9)
			bs.mesh = bb
			bs.position = Vector3(sx * half, (wall_h + 2.6) * 0.5, sz * half)
			var bmat := StandardMaterial3D.new()
			bmat.albedo_texture = tex
			bmat.uv1_scale = Vector3(0.8, 1.0, 1.0)
			bmat.metallic = 0.4
			bmat.roughness = 0.5
			bs.mesh.material = bmat
			root.add_child(bs)
			## celah tembak cyan di atas bastion (emissive tipis)
			var slit := MeshInstance3D.new()
			slit.name = "BastionSlit_%d" % bastion_count
			var sm := BoxMesh.new()
			sm.size = Vector3(6.4, 0.25, 6.4)
			slit.mesh = sm
			slit.position = bs.position + Vector3(0, (wall_h + 2.6) * 0.5 + 0.15, 0)
			var slit_mat := StandardMaterial3D.new()
			slit_mat.albedo_color = Color(0.2, 0.85, 1.0)
			slit_mat.emission_enabled = true
			slit_mat.emission = Color(0.2, 0.85, 1.0)
			slit_mat.emission_energy_multiplier = 1.6
			slit.mesh.material = slit_mat
			root.add_child(slit)
			bastion_count += 1
	print("QA:ARENA:FORTRESS src=png walls=%d bastions=%d gates=4 wall_h=%.1f tex=rampart_wall" % [
		wall_count, bastion_count, wall_h])


func _create_platform_rim() -> void:
	## Tepi platform emissive + pylon sudut: arena terbaca sebagai PLATFORM
	## (bukan bidang tak berujung) — perbaikan "canvas 3D masih prototype".
	var rim := Node3D.new()
	rim.name = "PlatformRim"
	add_child(rim)
	var edge := ARENA_SIZE
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
	if _menu_idle:
		_menu_camera_idle(delta)  ## M3 #4: base hidup di belakang menu
	elif rig != null:
		rig.apply(delta)  ## M3 #6: zoom/pan pemain (smoothing + clamp)
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


# ------------------------------------------------------------ kamera -------
func _on_camera_zoom_requested(zoom_in: bool) -> void:
	## Tombol HUD (eksplisit) — sama dengan gesture, satu jalur kode.
	if rig == null:
		return
	if zoom_in:
		rig.zoom_in()
	else:
		rig.zoom_out()
	rig.apply_now()
	QaMarkers.marker("CAM", "BUTTON", {"zoom_in": zoom_in, "scale": snappedf(rig.scale(), 0.01)})


func _on_viewport_resized_camera() -> void:
	## Rotasi/resize browser: batas pandang & zoom fit kamera dihitung ulang.
	if rig != null:
		rig.on_viewport_resized()


func _on_camera_reset_requested() -> void:
	if rig == null:
		return
	rig.reset()
	rig.apply_now()
	QaMarkers.marker("CAM", "BUTTON", {"reset": true, "scale": snappedf(rig.scale(), 0.01)})


## API untuk test/showcase: zoom & pan tanpa event (deterministik).
func camera_set_scale(s: float) -> void:
	if rig != null:
		rig.set_scale(s)
		rig.apply_now()


func camera_pan_world(dx: float, dz: float) -> void:
	if rig != null:
		rig.pan_by_world(dx, dz)
		rig.apply_now()


func camera_reset() -> void:
	if rig != null:
		rig.reset()
		rig.apply_now()


func audit_label_hud_overlap() -> Dictionary:
	## Ukur ULANG (bukan asumsi): label dunia yang terlihat vs zona HUD terlihat.
	## Dipakai showcase/gate untuk membuktikan label tidak menembus panel
	## (khususnya saat kamera di-zoom dekat / di-pan).
	var bs: BuildingSystem = $BuildingSystem
	var chrome: Array = []
	if hud != null:
		for z in hud.get_chrome_rects():
			chrome.append(z["rect"])
	var visible := 0
	var hidden_by_hud := 0
	var overlap := 0
	for b in bs.get_all_buildings():
		if b.is_destroyed() or not b.visible:
			continue
		if not b.label_visible():
			hidden_by_hud += 1
			continue
		visible += 1
		var r: Rect2 = b.label_screen_rect(camera)
		for cr in chrome:
			if r.intersects(cr):
				overlap += 1
				break
	return {"visible": visible, "overlap": overlap, "hidden": hidden_by_hud,
		"zones": chrome.size()}


func _menu_camera_idle(delta: float) -> void:
	## Kamera strategis idle: orbit yaw ±5,7° + dolly ±3,5% mengelilingi base
	## (pola "village hidup" Clash of Clans / Doomsday) — halus, bukan cut.
	_menu_t += delta
	var yaw := sin(_menu_t * 0.18) * 0.10
	var zoom := 1.0 + sin(_menu_t * 0.11 + 1.2) * 0.035
	var off := (_cam_base_pos - _cam_focus).rotated(Vector3.UP, yaw) * zoom
	camera.position = _cam_focus + off
	camera.look_at(_cam_focus, Vector3.UP)


# ---------------------------------------------------------- label 3D ----
func _declutter_labels() -> void:
	## ANTI-TUMPUK teks di canvas 3D: label dunia yang kotaknya beririsan di
	## ruang layar disembunyikan (prioritas: bangunan terpilih, lalu terdekat
	## kamera). Setelah penempatan, jumlah irisan DIUKUR ULANG (bukan asumsi)
	## dan dilaporkan sebagai marker QA:SCENE:LABEL_OVERLAP — verifikasi terukur.
	var bs: BuildingSystem = $BuildingSystem
	if bs == null:
		return
	if _menu_idle:
		## M3 #4: di MENU, label dunia = chrome → SEMUA disembunyikan supaya
		## panel menu tidak pernah ditimpa teks 3D di aspek/resolusi mana pun.
		for b in bs.get_all_buildings():
			b.set_label_visible(false)
		if _label_menu_state != "hidden":
			_label_menu_state = "hidden"
			print("QA:SCENE:LABEL_MENU state=hidden total=%d" % bs.get_all_buildings().size())
		return
	if _label_menu_state != "world":
		_label_menu_state = "world"
		print("QA:SCENE:LABEL_MENU state=world")
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
		var rect: Rect2 = b.label_screen_rect(camera)  ## geometri nyata (semua zoom)
		if rect.size == Vector2.ZERO:
			rect = Rect2(sp - b.label_extent_px() * 0.5, b.label_extent_px())
		entries.append({
			"b": b,
			"sp": sp,
			"rect": rect,
			"d": camera.global_position.distance_to(wp),
			"sel": b.instance_id == _arrow_target,
		})
	entries.sort_custom(func(a, c):
		if a["sel"] != c["sel"]:
			return a["sel"]  ## yang terpilih selalu menang
		return a["d"] < c["d"])
	## Zona HUD yang terlihat = area TERTUTUP bagi label dunia (kritik #3). Zoom
	## dekat menggeser label ke atas panel (temuan foto M3 #6) → label yang
	## menembus panel disembunyikan, bukan dibiarkan menumpuk.
	var chrome: Array = []
	if hud != null:
		for z in hud.get_chrome_rects():
			chrome.append(z["rect"])
	var placed: Array = []
	var hud_clash := 0
	for e in entries:
		var r: Rect2 = e["rect"]
		var clash := false
		for p in placed:
			if r.intersects(p):
				clash = true
				break
		if not clash:
			for cr in chrome:
				if r.intersects(cr):
					clash = true
					hud_clash += 1
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
	## Verifikasi terukur: label yang terlihat TIDAK boleh menembus zona HUD.
	var hud_overlap := 0
	for r2 in placed:
		for cr2 in chrome:
			if (r2 as Rect2).intersects(cr2):
				hud_overlap += 1
	var sig := "%d/%d/%d/%d/%d/%d" % [placed.size(), entries.size() - placed.size(),
		entries.size(), overlap, hud_overlap, hud_clash]
	if sig != _label_db:  ## hanya saat berubah (hindari spam log)
		_label_db = sig
		print("QA:SCENE:LABEL_HUD_OVERLAP count=%d hidden_by_hud=%d zones=%d" % [
			hud_overlap, hud_clash, chrome.size()])
		print("QA:SCENE:LABEL_OVERLAP count=%d visible=%d hidden=%d total=%d" % [
			overlap, placed.size(), entries.size() - placed.size(), entries.size()])
		for e in entries:
			print("QA:SCENE:LABEL_DBG text=%s at=(%d,%d) vis=%s" % [
				e["b"].label_text(), int((e["sp"] as Vector2).x), int((e["sp"] as Vector2).y),
				str(e["b"].label_visible())])


# ------------------------------------------------------------- pick ----
func get_hud() -> Control:
	## Dipakai showcase input (mode `input`) untuk menguji jalur klik nyata.
	return hud


func get_camera_rig():
	return rig


func _unhandled_input(event: InputEvent) -> void:
	if placement_active():
		## M3 #9: di mode penempatan, input = MENGATUR HANTU (bukan pick
		## bangunan & bukan kamera): gerak = pindah hantu, ESC = batal.
		## Konfirmasi lewat tombol KONFIRMASI di bilah penempatan HUD.
		if event is InputEventMouseMotion:
			update_placement_at(placement_mm_to_ground((event as InputEventMouseMotion).position))
			return
		if event is InputEventMouseButton:
			var pmb := event as InputEventMouseButton
			if pmb.pressed and pmb.button_index == MOUSE_BUTTON_LEFT:
				update_placement_at(placement_mm_to_ground(pmb.position))
				return
			if pmb.pressed and pmb.button_index == MOUSE_BUTTON_RIGHT:
				cancel_placement()
				return
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			update_placement_at(placement_mm_to_ground((event as InputEventScreenTouch).position))
			return
		if event is InputEventKey and (event as InputEventKey).pressed \
				and (event as InputEventKey).keycode == KEY_ESCAPE:
			cancel_placement()
			return
		return
	if hud != null and (hud.is_build_menu_open() or hud.is_ship_menu_open()
			or hud.is_pause_menu_open() or hud.is_main_menu_open()):
		return  ## modal/menu terbuka — jangan pick
	## M3 #6: gesture kamera (pinch/drag/wheel/double tap) DIKONSUMSI rig →
	## tap pendek tetap diteruskan supaya pemilihan bangunan tidak hilang.
	if rig != null and rig.handle_event(event):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		## Pick pada RELEASE, bukan press: menekan lalu MENG GESER = pan kamera
		## (drag kiri), tarikan itu tidak boleh ikut memilih bangunan.
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_pick(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pick(st.position)


# =====================================================================
# M3 #9 — MODE PENEMPATAN (ghost) — logika build game strategi
# ---------------------------------------------------------------------
# Alur (riset: Clash of Clans / Last War; lihat laporan M3 #9 §2):
#   katalog → tekan BANGUN → katalog TUTUP → bangunan hantu mengikuti penunjuk
#   → hijau = sah / merah = tidak (dengan ALASAN yang dibaca pemain) → tombol
#   KONFIRMASI membayar + memasukkan antrian konstruksi; BATAL = tanpa biaya.
# =====================================================================
var _placing_id: StringName = &""
var _ghost: Node3D = null
var _ghost_plate: MeshInstance3D = null
var _ghost_pos := Vector3.ZERO
var _ghost_valid := false
var _ghost_reason := ""
var _ghost_last_key := ""


func placement_active() -> bool:
	return _placing_id != &""


func placement_id() -> StringName:
	return _placing_id


func placement_state() -> Dictionary:
	var def := GameData.get_building_def(_placing_id)
	return {"id": _placing_id, "active": placement_active(),
		"name": def.display_name if def != null else "",
		"pos": "%.0f,%.0f" % [_ghost_pos.x, _ghost_pos.z],
		"valid": _ghost_valid, "reason": _ghost_reason}


func _on_placement_requested(def_id: StringName) -> void:
	enter_placement(def_id)


func enter_placement(def_id: StringName) -> bool:
	## Masuk mode penempatan untuk `def_id` (dipanggil tombol BANGUN di katalog).
	var def := GameData.get_building_def(def_id)
	var bs: BuildingSystem = $BuildingSystem
	if def == null or bs == null:
		return false
	cancel_placement(false)   ## satu mode pada satu waktu
	_placing_id = def_id
	_ghost = BuildingModel.make(def_id, def.footprint)
	_ghost.name = "PlacementGhost"
	add_child(_ghost)
	## pelat footprint + bracket sudut (penanda area grid yang akan ditempati)
	_ghost_plate = MeshInstance3D.new()
	_ghost_plate.name = "GhostPlate"
	var pm := BoxMesh.new()
	var w := float(def.footprint.x) * BuildingSystem.GRID_SPACING
	var d := float(def.footprint.y) * BuildingSystem.GRID_SPACING
	pm.size = Vector3(w, 0.08, d)
	_ghost_plate.mesh = pm
	_ghost_plate.position = Vector3(0, 0.05, 0)
	add_child(_ghost_plate)
	## mulai dari slot kosong otomatis supaya pemain langsung melihat tawaran sah
	var start := bs.snap_to_grid(bs.next_free_position(def.footprint))
	update_placement_at(start)
	QaMarkers.marker("BUILD", "PLACEMENT", {"id": def_id, "footprint": "%dx%d" % [
		def.footprint.x, def.footprint.y], "area": "±%.0f" % BuildingSystem.PLATE_HALF})
	return true


func update_placement_at(world_pos: Vector3) -> void:
	## Perbarui posisi hantu: snap ke grid, validasi, warnai, laporkan keadaan.
	if not placement_active():
		return
	var bs: BuildingSystem = $BuildingSystem
	var want := bs.snap_to_grid(world_pos)
	var check := bs.can_place(_placing_id, want)
	_ghost_pos = want
	_ghost_valid = bool(check["ok"])
	_ghost_reason = String(check["reason"])
	var col := Color(0.25, 1.0, 0.45) if _ghost_valid else Color(1.0, 0.32, 0.30)
	if _ghost != null:
		_ghost.position = want
		BuildingModel.tint(_ghost, col, 0.9)
	if _ghost_plate != null:
		_ghost_plate.position = want + Vector3(0, 0.05, 0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(col.r, col.g, col.b, 0.30)
		pmat.emission_enabled = true
		pmat.emission = col
		pmat.emission_energy_multiplier = 0.6
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_plate.mesh.material = pmat
	var key := "%s|%s|%s" % ["%.0f,%.0f" % [want.x, want.z], str(_ghost_valid), _ghost_reason]
	if key != _ghost_last_key:
		_ghost_last_key = key
		QaMarkers.marker("BUILD", "GHOST", {"id": _placing_id,
			"pos": "%.0f,%.0f" % [want.x, want.z], "valid": _ghost_valid,
			"reason": _ghost_reason})
	if hud != null and hud.has_method("set_placement_state"):
		hud.call("set_placement_state", placement_state())


func placement_mm_to_ground(rel: Vector2) -> Vector3:
	## Konversi titik layar → titik di bidang tanah (y=0) memakai kamera nyata.
	var origin := camera.project_ray_origin(rel)
	var dir := camera.project_ray_normal(rel)
	if absf(dir.y) < 0.0001:
		return _ghost_pos
	return origin + dir * (-origin.y / dir.y)


func confirm_placement() -> Dictionary:
	if not placement_active():
		return {"ok": false, "reason": "tidak_ada_mode"}
	var bs: BuildingSystem = $BuildingSystem
	var ps = SystemRefs.production_system()
	var def := GameData.get_building_def(_placing_id)
	if not _ghost_valid:
		## Invarian UI: aksi yang ditolak SELALU dijawab (toast + status bilah),
		## tidak pernah "tombol yang diam" (kritik pemain "tidak bisa diklik").
		var human := {"di_luar_plataran": "Di luar plataran benteng",
			"sudah_terisi": "Sudah ada bangunan di area ini",
			"bangunan_tidak_dikenal": "Bangunan tidak dikenal"}.get(_ghost_reason, _ghost_reason)
		EventBus.ui_message.emit(tr("Tidak bisa menempatkan: ") + tr(human), "warning")
		QaMarkers.marker("BUILD", "CONFIRM_REJECT", {"id": _placing_id, "reason": _ghost_reason,
			"pos": "%.0f,%.0f" % [_ghost_pos.x, _ghost_pos.z]})
		return {"ok": false, "reason": _ghost_reason}
	if def == null or ps == null or not Economy.can_afford(def.base_cost):
		QaMarkers.marker("BUILD", "CONFIRM_REJECT", {"id": _placing_id, "reason": "sumber_daya_kurang"})
		return {"ok": false, "reason": "sumber_daya_kurang"}
	var id := _placing_id
	var ok: bool = ps.enqueue_construction(id, _ghost_pos)
	QaMarkers.marker("BUILD", "CONFIRM", {"id": id, "ok": ok,
		"pos": "%.0f,%.0f" % [_ghost_pos.x, _ghost_pos.z],
		"grid": "%d,%d" % [BuildingSystem._cell(_ghost_pos.x), BuildingSystem._cell(_ghost_pos.z)]})
	cancel_placement(false)
	EventBus.placement_finished.emit(id, ok, "ok" if ok else "antrian_gagal")
	return {"ok": ok, "reason": "ok" if ok else "antrian_gagal"}


func cancel_placement(emit_signal_done: bool = true) -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _ghost_plate != null:
		_ghost_plate.queue_free()
		_ghost_plate = null
	var had := _placing_id
	_placing_id = &""
	_ghost_last_key = ""
	if hud != null and hud.has_method("set_placement_state"):
		hud.call("set_placement_state", {"active": false, "id": &"", "valid": false, "reason": ""})
	if had != &"" and emit_signal_done:
		QaMarkers.marker("BUILD", "PLACEMENT_CANCEL", {"id": had})
		EventBus.placement_finished.emit(had, false, "batal")


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
