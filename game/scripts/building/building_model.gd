class_name BuildingModel
extends RefCounted
## BuildingModel — SUMBER MODEL BANGUNAN.
##
## M3 #9 (kritik pemain 2026-10-16: "bangunan/komponen masih pakai code, bukan
## asset"): model sekarang berasal dari **BERKAS ASET** hasil Blender
## (tools/blender/make_fortress.py) → `game/assets/fortress/<slug>.mesh.json`
## (+ .tscn shell). Tidak ada lagi geometri bangunan yang digambar dari kode.
## Rantai: Blender (.blend source + .glb + mesh.json) → AssetModelScene runtime.
##
## Blok `match id` di bawah adalah JALUR CADANGAN (fallback) yang hanya dipakai
## bila berkas aset tidak ada (mis. build lama) — supaya game tidak pernah gagal
## render. Bila aset ada, geometri kode TIDAK dipakai sama sekali.
##
## Latar belakang (kritik user 2026-10-12): "canvas 3D masih prototype" —
## bangunan hanya kotak berwarna. Model di sini adalah struktur komposit dari
## primitif Godot (BoxMesh/CylinderMesh/SphereMesh/TorusMesh/PrismMesh) dengan
## siluet berbeda per tipe + aksen emissive, jadi tiap bangunan terbaca tanpa
## label. Tidak ada aset eksternal (build web tidak punya loader .glb/.png saat
## runtime), semua parameter tetap (tanpa RNG) → reproducible untuk QA.
##
## Dipakai Building (`building.gd`). Fallback tetap ada: bila id tidak dikenal,
## `make()` mengembalikan null dan Building memakai kotak lama (tidak pernah
## crash/gagal render — sama seperti kapal).

## Benchmark mode (stress/perf): model diganti kotak sederhana → draw call
## benchmark mengukur gameplay (kapal + sistem), bukan dekorasi. Sama prinsipnya
## dengan `BaseScene.reduce_environment_for_benchmark()`.
static var simple_mode := false

const _MAT_CACHE := {}


const ASSET_DIR := "res://assets/fortress"
## id bangunan → slug aset (MASTER_ASSET_INVENTORY: FRT-002/ECO-001/ECO-004/
## ECO-010/DEF-001/DEF-008). Nama berkas memakai ID aset (kontrak §2).
const ASSET_BY_ID := {
	&"command_core": "frt-002",
	&"energy_reactor": "eco-001",
	&"mineral_extractor": "eco-004",
	&"fighter_hangar": "eco-010",
	&"laser_turret": "def-001",
	&"shield_generator": "def-008",
}


static func make(id: StringName, footprint: Vector2i) -> Node3D:
	## Bangun struktur untuk satu tipe bangunan: ASET dulu, kode sebagai cadangan.
	if simple_mode:
		return _simple_proxy(footprint)
	var asset := from_asset(id)
	if asset != null:
		return asset
	match id:
		&"command_core":
			return _command_core()
		&"energy_reactor":
			return _energy_reactor()
		&"mineral_extractor":
			return _mineral_extractor()
		&"fighter_hangar":
			return _fighter_hangar()
		&"laser_turret":
			return _laser_turret()
		&"shield_generator":
			return _shield_generator()
	return null


static func from_asset(id: StringName) -> Node3D:
	## Muat model dari berkas aset. Null = aset tidak ada (pemanggil pakai cadangan).
	if not ASSET_BY_ID.has(id):
		return null
	var slug: String = ASSET_BY_ID[id]
	var path := "%s/%s.tscn" % [ASSET_DIR, slug]
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var node: Node3D = scene.instantiate()
	node.name = "AssetModel"
	QaMarkers.marker("MODEL", "ASSET", {"id": String(id), "asset": slug,
		"src": "assets/fortress/%s.mesh.json" % slug})
	return node


static func asset_scene_path(id: StringName) -> String:
	## Jalur berkas aset untuk satu tipe (dipakai gate/audit & UI kartu).
	if not ASSET_BY_ID.has(id):
		return ""
	return "%s/%s.tscn" % [ASSET_DIR, ASSET_BY_ID[id]]


static func is_asset_backed(id: StringName) -> bool:
	return asset_scene_path(id) != "" and ResourceLoader.exists(asset_scene_path(id))


static func group_aabb(root: Node3D) -> AABB:
	## AABB gabungan mesh langsung anak root (aset dibangun rata di bawah root).
	var out := AABB()
	var first := true
	for c in root.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		box.position += mi.position
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


## Gain tinggi per tipe: aset dibuat berskala nyata, tapi di kamera strategis
## bangunan harus MENJULANG (Game_Concept.md §7: "benteng monumental, bukan
## kumpulan bangunan kecil yang hampir tidak terlihat"). Lebar tetap di dalam
## slot grid; hanya tinggi yang ditinggikan → tidak ada tumpang-tindih.
const VERTICAL_GAIN := {
	&"command_core": 1.75,
	&"fighter_hangar": 1.30,
	&"energy_reactor": 1.35,
	&"mineral_extractor": 1.40,
	&"laser_turret": 1.20,
	&"shield_generator": 1.30,
}


static func fit_to_slot(root: Node3D, footprint: Vector2i, id: StringName = &"") -> void:
	## Aset punya ukuran METER ASLI (kontrak skala 1 unit = 1 m); slot grid
	## bangunan 2 m × footprint. Skala dulu supaya bangunan mengisi slot dengan
	## rapi (tanpa ini Command Core 8,5 m akan menimpa tetangganya di slot 3×3).
	if root == null:
		return
	var box := group_aabb(root)
	var span := maxf(box.size.x, box.size.z)
	if span <= 0.001:
		return
	var slot := maxf(2.0, float(maxi(footprint.x, footprint.y)) * BuildingSystem.GRID_SPACING)
	var scale_f := (slot * 0.95) / span
	var gain := float(VERTICAL_GAIN.get(id, 1.25))
	root.scale = Vector3(scale_f, scale_f * gain, scale_f)
	root.position.y = -box.position.y * scale_f * gain  ## dasar menempel dek (y = 0)


static func animate(root: Node3D, delta: float, t: float) -> void:
	## Animasi idle murah (dipanggil Building._process): antena/stabilizer
	## berputar, inti reaktor berdenyut. Tidak memakai Tween/shader.
	if root == null:
		return
	var spin := root.get_node_or_null("Spin")
	if spin is Node3D:
		(spin as Node3D).rotate_y(delta * 0.8)
	## Mesh ASET: denyut halus untuk semua material emissive (inti reaktor,
	## pintu hanggar, ujung laras) — memberi "kehidupan" tanpa shader mahal.
	for mi_any in root.find_children("*", "MeshInstance3D", true, false):
		var m_any := (mi_any as MeshInstance3D).mesh
		if m_any == null:
			continue
		var mat_any := m_any.material as StandardMaterial3D
		if mat_any == null or not mat_any.emission_enabled:
			continue
		if mat_any.emission_energy_multiplier > 1.0:
			mat_any.emission_energy_multiplier = 1.0 + 0.45 * sin(t * 2.2)
	for core in root.find_children("Pulse*", "MeshInstance3D", true, false):
		var mi := core as MeshInstance3D
		var mat := mi.mesh.material as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			mat.emission_energy_multiplier = 1.0 + 0.55 * sin(t * 2.4)


static func tint(root: Node3D, color: Color, emission_scale: float) -> void:
	## Pewarnaan state (NORMAL/DAMAGED/CRITICAL/DESTROYED) untuk SEMUA mesh
	## struktur — material tiap mesh unik (dibuat per instance), aman diubah.
	if root == null:
		return
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var mat := m.material as StandardMaterial3D
		if mat == null:
			continue
		mat.albedo_color = color
		if mat.emission_enabled:
			mat.emission = color * emission_scale


# ------------------------------------------------------------- tipe ----
static func _command_core() -> Node3D:
	## Pusat Komando (HQ): siluet bertingkat + pilar + kubah + antena.
	var n := Node3D.new()
	n.name = "CommandCoreModel"
	n.add_child(_cyl("Base", 4.2, 0.7, Vector3.ZERO, C_GOLD_DARK, 0.0, 8))
	n.add_child(_box("Deck1", Vector3(4.6, 0.5, 4.6), Vector3(0, 0.95, 0), C_METAL))
	n.add_child(_box("Deck2", Vector3(3.2, 0.5, 3.2), Vector3(0, 1.45, 0), C_METAL_DARK))
	# menara utama + jendela emissive (garis hangat)
	n.add_child(_box("Tower", Vector3(2.6, 2.4, 2.6), Vector3(0, 2.9, 0), C_METAL))
	n.add_child(_box("WindowBand", Vector3(2.72, 0.35, 2.72), Vector3(0, 3.35, 0), C_GOLD, 2.2))
	n.add_child(_box("WindowBand2", Vector3(2.72, 0.22, 2.72), Vector3(0, 2.35, 0), C_GOLD, 1.4))
	# kubah + antena + lampu
	n.add_child(_sphere("Dome", 1.25, Vector3(0, 4.35, 0), C_METAL))
	n.add_child(_cyl("Antenna", 0.09, 2.6, Vector3(0, 5.6, 0), C_METAL_DARK))
	n.add_child(_sphere("PulseTip", 0.22, Vector3(0, 6.95, 0), C_GOLD, 3.0))
	# 4 pilar sudut + strut silang
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + PI / 4.0
		var p := Vector3(cos(ang) * 2.9, 1.6, sin(ang) * 2.9)
		n.add_child(_cyl("Pillar_%d" % i, 0.22, 3.2, p, C_METAL_DARK))
		n.add_child(_box("Brace_%d" % i, Vector3(0.16, 0.16, 2.4),
			Vector3(cos(ang) * 1.9, 2.6, sin(ang) * 1.9), C_METAL_DARK,
			0.0, Vector3(0, -ang + PI / 4.0, 0)))
	return n


static func _energy_reactor() -> Node3D:
	## Reaktor Energi: alas silinder + cincin torus + inti berdenyut + strut.
	var n := Node3D.new()
	n.name = "EnergyReactorModel"
	n.add_child(_cyl("Base", 2.2, 1.0, Vector3.ZERO, C_METAL_DARK, 0.0, 12))
	n.add_child(_cyl("Plating", 1.7, 0.4, Vector3(0, 1.15, 0), C_METAL))
	# inti emissive (berdenyut lewat animate())
	n.add_child(_sphere("PulseCore", 0.85, Vector3(0, 2.05, 0), C_CYAN, 3.2))
	n.add_child(_torus("Ring", 1.55, 0.16, Vector3(0, 2.05, 0), C_CYAN, 2.0))
	n.add_child(_torus("Ring2", 1.15, 0.1, Vector3(0, 1.55, 0), C_CYAN, 1.4))
	# 3 strut penopang + penutup atas
	for i in range(3):
		var ang := TAU * float(i) / 3.0
		n.add_child(_box("Strut_%d" % i, Vector3(0.3, 2.1, 0.3),
			Vector3(cos(ang) * 1.35, 1.3, sin(ang) * 1.35), C_METAL,
			0.0, Vector3(0, 0, 0.28 * cos(ang))))
	n.add_child(_cyl("Cap", 0.7, 0.3, Vector3(0, 3.0, 0), C_METAL_DARK))
	n.add_child(_sphere("PulseCap", 0.2, Vector3(0, 3.25, 0), C_CYAN, 2.4))
	return n


static func _mineral_extractor() -> Node3D:
	## Ekstraktor Mineral: tripod + bor berputar + hopper (warna amber mineral).
	var n := Node3D.new()
	n.name = "MineralExtractorModel"
	n.add_child(_cyl("Pad", 1.9, 0.35, Vector3.ZERO, C_METAL_DARK, 0.0, 8))
	for i in range(3):
		var ang := TAU * float(i) / 3.0 + PI / 6.0
		n.add_child(_box("Leg_%d" % i, Vector3(0.28, 2.6, 0.28),
			Vector3(cos(ang) * 1.25, 1.5, sin(ang) * 1.25), C_METAL,
			0.0, Vector3(0.22 * sin(ang), 0, -0.22 * cos(ang))))
	# kepala bor berputar (node "Spin" → animate())
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0, 3.0, 0)
	n.add_child(spin)
	spin.add_child(_box("Head", Vector3(1.7, 0.6, 1.7), Vector3.ZERO, C_METAL))
	spin.add_child(_cyl("Drive", 1.35, 0.35, Vector3(0, -0.45, 0), C_CYAN, 1.6, 10))
	spin.add_child(_box("Bit", Vector3(0.3, 1.6, 0.3), Vector3(0, -1.3, 0), C_METAL_DARK))
	spin.add_child(_sphere("PulseDrill", 0.3, Vector3(0, -2.2, 0), C_AMBER, 2.6))
	n.add_child(_box("Hopper", Vector3(1.5, 0.9, 1.2), Vector3(1.2, 0.9, 0), C_METAL_DARK))
	n.add_child(_box("Ore", Vector3(1.1, 0.25, 0.85), Vector3(1.2, 1.45, 0), C_AMBER, 1.0))
	return n


static func _fighter_hangar() -> Node3D:
	## Hangar Pesawat: hangar besar + atap lengkung + pintu + lampu landasan.
	var n := Node3D.new()
	n.name = "FighterHangarModel"
	n.add_child(_box("Body", Vector3(5.4, 1.7, 3.8), Vector3(0, 0.85, 0), C_METAL_DARK))
	# atap lengkung: silinder rebah (separuh tampak sebagai vault)
	var roof := _cyl("Roof", 1.9, 5.4, Vector3(0, 1.7, 0), C_METAL, 0.0, 14)
	(roof as MeshInstance3D).rotation = Vector3(0, 0, PI / 2)
	n.add_child(roof)
	# pintu hangar (gelap) + garis emissive hijau + lampu landasan
	n.add_child(_box("Door", Vector3(3.2, 1.3, 0.2), Vector3(0, 0.75, -1.95), C_BLACK))
	n.add_child(_box("DoorGlow", Vector3(3.2, 0.12, 0.24), Vector3(0, 1.45, -1.95), C_GREEN, 2.4))
	for i in range(3):
		n.add_child(_sphere("PulseRunway_%d" % i, 0.16,
			Vector3(-1.6 + float(i) * 1.6, 0.12, -2.6), C_GREEN, 2.0))
	n.add_child(_box("Tower", Vector3(0.9, 1.9, 0.9), Vector3(2.4, 2.6, 1.2), C_METAL))
	n.add_child(_sphere("PulseBeacon", 0.2, Vector3(2.4, 3.65, 1.2), C_GREEN, 2.6))
	return n


static func _laser_turret() -> Node3D:
	## Turret Laser: alas + kepala berputar + laras ganda (pertahanan).
	var n := Node3D.new()
	n.name = "LaserTurretModel"
	n.add_child(_cyl("Base", 1.15, 0.6, Vector3.ZERO, C_METAL_DARK, 0.0, 8))
	n.add_child(_cyl("Ring", 0.85, 0.25, Vector3(0, 0.65, 0), C_METAL))
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0, 0.95, 0)
	n.add_child(spin)
	spin.add_child(_box("Head", Vector3(1.2, 0.7, 1.4), Vector3.ZERO, C_METAL))
	spin.add_child(_box("Visor", Vector3(1.24, 0.18, 1.44), Vector3(0, 0.2, 0), C_RED, 2.2))
	for dx in [-0.35, 0.35]:
		var barrel := _cyl("Barrel_%s" % ("L" if dx < 0 else "R"), 0.12, 1.9,
			Vector3(dx, 0.1, -1.5), C_METAL_DARK, 0.0, 8)
		(barrel as MeshInstance3D).rotation = Vector3(PI / 2, 0, 0)
		spin.add_child(barrel)
		spin.add_child(_sphere("PulseMuzzle_%s" % ("L" if dx < 0 else "R"), 0.1,
			Vector3(dx, 0.1, -2.4), C_RED, 2.8))
	spin.add_child(_sphere("PulseSensor", 0.14, Vector3(0, 0.55, 0.5), C_RED, 2.2))
	return n


static func _shield_generator() -> Node3D:
	## Generator Perisai: alas + 3 prong pemancar + bola perisai transparan.
	var n := Node3D.new()
	n.name = "ShieldGeneratorModel"
	n.add_child(_cyl("Base", 1.9, 0.6, Vector3.ZERO, C_METAL_DARK, 0.0, 10))
	n.add_child(_cyl("Hub", 0.9, 0.7, Vector3(0, 0.75, 0), C_METAL))
	n.add_child(_sphere("PulseEmitter", 0.5, Vector3(0, 1.35, 0), C_BLUE, 2.6))
	for i in range(3):
		var ang := TAU * float(i) / 3.0
		n.add_child(_box("Prong_%d" % i, Vector3(0.26, 2.2, 0.26),
			Vector3(cos(ang) * 1.35, 1.4, sin(ang) * 1.35), C_METAL,
			0.0, Vector3(0, 0, 0.3 * cos(ang))))
		n.add_child(_sphere("PulseProng_%d" % i, 0.18,
			Vector3(cos(ang) * 1.35, 2.55, sin(ang) * 1.35), C_BLUE, 2.2))
	# bola perisai (transparan + emissive tipis)
	var dome := _sphere("ShieldDome", 2.5, Vector3(0, 1.4, 0), C_BLUE, 0.5)
	var dmat := (dome as MeshInstance3D).mesh.material as StandardMaterial3D
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.16)
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.name = "PulseShieldDome"
	n.add_child(dome)
	return n


static func _simple_proxy(footprint: Vector2i) -> Node3D:
	## Proksi benchmark: kotak + penanda inti emissive (2 mesh) — pengukuran
	## gameplay tidak terpengaruh dekorasi bangunan (dilaporkan jujur di M37_REPORT).
	var n := Node3D.new()
	n.name = "SimpleProxy"
	var w := maxf(1.0, float(footprint.x)) * 1.5
	var d := maxf(1.0, float(footprint.y)) * 1.5
	n.add_child(_box("Body", Vector3(w, 1.5, d), Vector3(0, 0.75, 0), C_METAL))
	n.add_child(_sphere("PulseCore", 0.25, Vector3(0, 1.7, 0), C_CYAN, 2.0))
	return n


# ----------------------------------------------------------- primitif ----
const C_METAL := Color(0.30, 0.34, 0.42)
const C_METAL_DARK := Color(0.19, 0.22, 0.29)
const C_BLACK := Color(0.06, 0.07, 0.10)
const C_GOLD := Color(0.95, 0.78, 0.32)
const C_GOLD_DARK := Color(0.55, 0.44, 0.18)
const C_CYAN := Color(0.35, 0.85, 1.0)
const C_AMBER := Color(0.95, 0.68, 0.25)
const C_GREEN := Color(0.35, 1.0, 0.55)
const C_RED := Color(1.0, 0.4, 0.35)
const C_BLUE := Color(0.45, 0.7, 1.0)


static func _mat(color: Color, emission: float) -> StandardMaterial3D:
	## Material unik per mesh (instance baru) → state tint aman diubah.
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	m.metallic = 0.35
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


static func _box(name: String, size: Vector3, pos: Vector3, color: Color,
		emission: float = 0.0, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color, emission)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	return mi


static func _cyl(name: String, radius: float, height: float, pos: Vector3,
		color: Color, emission: float = 0.0, sides: int = 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.material = _mat(color, emission)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = cm
	mi.position = pos
	return mi


static func _sphere(name: String, radius: float, pos: Vector3, color: Color,
		emission: float = 0.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = _mat(color, emission)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = sm
	mi.position = pos
	return mi


static func _torus(name: String, radius: float, tube: float, pos: Vector3,
		color: Color, emission: float = 0.0) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = radius - tube
	tm.outer_radius = radius + tube
	tm.rings = 16
	tm.ring_segments = 8
	tm.material = _mat(color, emission)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = tm
	mi.position = pos
	return mi
