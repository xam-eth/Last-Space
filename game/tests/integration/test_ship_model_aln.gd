extends RefCounted
## TestShipModelAln — acceptance pilot asset ALN-001 "Alien Scout"
## (ASSET_ACCEPTANCE_CRITERIA.md §2, mirror test_ship_model.gd untuk sisi alien):
## load scene runtime (tscn + mesh.json hasil konversi GLB), naming node,
## orientasi (depan -Z), skala 2–6 m, material + tekstur (MAT-002 chitin gelap,
## inti/mesin hijau emissive, senjata ungu emissive), poly budget, integrasi Ship
## (model_root + collision hull).
## Semua cek dari data nyata (instance hasil load, bukan asumsi).

func run(t) -> void:
	var def := GameData.get_ship_def(&"aln_001_scout")
	t.check("aln.def_present", def != null)
	if def == null:
		return
	t.check("aln.model_path_set", def.model_path != "", def.model_path)
	# artefak pipeline ter-pack: mesh data JSON harus ada di PCK
	t.check("aln.mesh_data_packed", FileAccess.file_exists("res://assets/ships/aln_001_scout.mesh.json"))
	var ps := load(def.model_path) as PackedScene
	t.check("aln.scene_loads", ps != null, def.model_path)
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	t.add_child(inst)  ## host = test runner (di tree)

	# naming node (kontrak ASSET_PIPELINE.md §2)
	var body := inst.find_child("ALN001_Body", true, false) as MeshInstance3D
	var eng := inst.find_child("ALN001_Engine_C", true, false) as MeshInstance3D
	var core := inst.find_child("ALN001_Core", true, false) as MeshInstance3D
	var wpn := inst.find_child("ALN001_Weapon_T", true, false) as MeshInstance3D
	t.check("aln.node_body", body != null)
	t.check("aln.nodes_named", eng != null and core != null and wpn != null)

	# skala: panjang model (extent Z) dalam kontrak kapal kecil 2–6 m
	var aabb := MeshUtil.model_aabb(inst)
	t.check("aln.scale_contract_2_6m", aabb.size.z >= 2.0 and aabb.size.z <= 6.0,
		"panjang_z=%.2f m" % aabb.size.z)

	# orientasi: nose (weapon) di -Z, engine di belakang (+Z)
	if wpn != null and eng != null:
		var z_wpn := MeshUtil.aabb_in_root(wpn, inst).get_center().z
		var z_eng := MeshUtil.aabb_in_root(eng, inst).get_center().z
		t.check("aln.orientation_nose_minus_z", z_wpn < z_eng,
			"weapon_z=%.2f engine_z=%.2f" % [z_wpn, z_eng])

	# material: hull MAT-002 (chitin gelap + tekstur), core/mesin hijau emissive,
	# senjata ungu emissive (ART_DIRECTION.md §2 — warna dari data nyata instance)
	if body != null and body.mesh != null:
		var mat := body.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("aln.hull_material", mat != null)
		if mat != null:
			t.check("aln.hull_textured", mat.albedo_texture != null)
			t.check("aln.hull_low_metallic", mat.metallic < 0.5, "metallic=%.2f" % mat.metallic)
			t.check("aln.poly_budget", MeshUtil.tri_count(body.mesh) < 5000,
				"tris=%d" % MeshUtil.tri_count(body.mesh))
			# kegelapan chitin diukur dari TEKSTUR aktual (decode pixel, data
			# nyata — albedo_color 0,8 default hanya faktor multiply di shader)
			if mat.albedo_texture != null:
				var img := mat.albedo_texture.get_image()
				if img != null:
					var lum := 0.0
					var n := 0
					for y in range(0, img.get_height(), 16):
						for x in range(0, img.get_width(), 16):
							var c := img.get_pixel(x, y)
							lum += (c.r + c.g + c.b) / 3.0
							n += 1
					lum /= float(n)
					t.check("aln.hull_dark", lum < 0.35, "mean_lum=%.3f (n=%d)" % [lum, n])
	if eng != null and eng.mesh != null:
		var emat := eng.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("aln.engine_emissive_green",
			emat != null and emat.emission_enabled
			and emat.emission.r < emat.emission.g and emat.emission.b < emat.emission.g,
			"emission=%s" % (emat.emission if emat != null else Color.BLACK))
	if core != null and core.mesh != null:
		var cmat := core.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("aln.core_emissive_green",
			cmat != null and cmat.emission_enabled
			and cmat.emission.r < cmat.emission.g and cmat.emission.b < cmat.emission.g,
			"emission=%s" % (cmat.emission if cmat != null else Color.BLACK))
	if wpn != null and wpn.mesh != null:
		var wmat := wpn.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("aln.weapon_emissive_purple",
			wmat != null and wmat.emission_enabled
			and wmat.emission.r > wmat.emission.g and wmat.emission.b > wmat.emission.g,
			"emission=%s" % (wmat.emission if wmat != null else Color.BLACK))

	# --- integrasi Ship: model_path → model_root + collision hull ---
	var s := Ship.new()
	s.setup(def, "test_aln_model_1")
	t.add_child(s)
	t.check("aln.ship_has_model_root", s.model_root != null)
	if s.model_root != null:
		var col := s.model_root.find_child("HullCollision", true, false) as StaticBody3D
		t.check("aln.ship_hull_collision", col != null)
		if col != null:
			var shape := col.find_child("*", true, false) as CollisionShape3D
			t.check("aln.collision_shape_box", shape != null and shape.shape is BoxShape3D)
			if shape != null and shape.shape is BoxShape3D:
				var sz := (shape.shape as BoxShape3D).size
				t.check("aln.collision_matches_hull", sz.z > 1.0 and sz.z < 7.0, "size=%s" % sz)
	s.queue_free()
	inst.queue_free()
