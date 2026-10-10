extends RefCounted
## TestShipModel — acceptance pilot asset SHP-001 (ASSET_ACCEPTANCE_CRITERIA.md §2):
## load scene runtime (tscn + mesh.json hasil konversi GLB), naming node,
## orientasi (depan -Z), skala 2–6 m, material + tekstur, poly budget,
## integrasi Ship (model_root + collision hull), fallback placeholder.
## Semua cek dari data nyata (instance hasil load, bukan asumsi).

func run(t) -> void:
	var def := GameData.get_ship_def(&"shp_001_interceptor")
	t.check("model.def_present", def != null)
	if def == null:
		return
	t.check("model.model_path_set", def.model_path != "", def.model_path)
	# artefak pipeline ter-pack: mesh data JSON harus ada di PCK
	t.check("model.mesh_data_packed", FileAccess.file_exists("res://assets/ships/shp_001_basic_interceptor.mesh.json"))
	var ps := load(def.model_path) as PackedScene
	t.check("model.scene_loads", ps != null, def.model_path)
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	t.add_child(inst)  ## host = test runner (di tree)

	# naming node (kontrak ASSET_PIPELINE.md §2)
	var body := inst.find_child("SHP001_Body", true, false) as MeshInstance3D
	var eng_l := inst.find_child("SHP001_Engine_L", true, false) as MeshInstance3D
	var eng_r := inst.find_child("SHP001_Engine_R", true, false) as MeshInstance3D
	var wpn := inst.find_child("SHP001_Weapon_T", true, false) as MeshInstance3D
	t.check("model.node_body", body != null)
	t.check("model.nodes_named", eng_l != null and eng_r != null and wpn != null)

	# skala: panjang model (extent Z) dalam kontrak kapal kecil 2–6 m
	var aabb := MeshUtil.model_aabb(inst)
	t.check("model.scale_contract_2_6m", aabb.size.z >= 2.0 and aabb.size.z <= 6.0,
		"panjang_z=%.2f m" % aabb.size.z)

	# orientasi: nose (weapon) di -Z, engine di belakang (+Z) — mengubah
	# ASSUMPTION di ASSET_PIPELINE.md §2 menjadi TERBUKTI/TERBANTah oleh data
	if wpn != null and eng_l != null:
		var z_wpn := MeshUtil.aabb_in_root(wpn, inst).get_center().z
		var z_eng := MeshUtil.aabb_in_root(eng_l, inst).get_center().z
		t.check("model.orientation_nose_minus_z", z_wpn < z_eng,
			"weapon_z=%.2f engine_z=%.2f" % [z_wpn, z_eng])

	# material: hull MAT-001 (metallic + tekstur), engine emissive (MAT-007)
	if body != null and body.mesh != null:
		var mat := body.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("model.hull_material", mat != null)
		if mat != null:
			t.check("model.hull_textured", mat.albedo_texture != null)
			t.check("model.hull_metallic", mat.metallic > 0.3, "metallic=%.2f" % mat.metallic)
		t.check("model.poly_budget", MeshUtil.tri_count(body.mesh) < 5000,
			"tris=%d" % MeshUtil.tri_count(body.mesh))
	if eng_l != null and eng_l.mesh != null:
		var emat := eng_l.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("model.engine_emissive", emat != null and emat.emission_enabled)

	# --- integrasi Ship: model_path → model_root + collision hull ---
	var s := Ship.new()
	s.setup(def, "test_model_1")
	t.add_child(s)
	t.check("model.ship_has_model_root", s.model_root != null)
	if s.model_root != null:
		var col := s.model_root.find_child("HullCollision", true, false) as StaticBody3D
		t.check("model.ship_hull_collision", col != null)
		if col != null:
			var shape := col.find_child("*", true, false) as CollisionShape3D
			t.check("model.collision_shape_box", shape != null and shape.shape is BoxShape3D)
			if shape != null and shape.shape is BoxShape3D:
				var sz := (shape.shape as BoxShape3D).size
				t.check("model.collision_matches_hull", sz.z > 1.0 and sz.z < 7.0, "size=%s" % sz)
	s.queue_free()

	# --- fallback: def tanpa model_path → placeholder box tetap jalan ---
	var def2 := ShipDef.new()
	def2.id = &"test_no_model"
	def2.max_hp = 10
	def2.model_path = ""
	var s2 := Ship.new()
	s2.setup(def2, "test_ph_1")
	t.add_child(s2)
	t.check("model.placeholder_fallback", s2.model_root == null and s2.get_child_count() == 1)
	s2.queue_free()
	inst.queue_free()
