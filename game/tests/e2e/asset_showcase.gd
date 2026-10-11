extends Node
## AssetShowcase — pilot asset SHP-001 di scene perwakilan (base game NYATA,
## bukan scene kosong: ASSET_ACCEPTANCE_CRITERIA.md §4 butir 2).
##
## Alur: spawn 6 interceptor (model GLB) → cek orientasi/skala/collision dari
## instance nyata → jalankan wave_1 (CombatVisualizer menampilkan model defender
## di battle view) → lapor hasil + QA:ASSET:READY.
## Screenshot oleh tools/vision/capture.mjs (mode=asset) = evidence visual.

var passed := 0
var failed := 0


func _ready() -> void:
	await get_tree().process_frame  ## tunggu base_scene siap (HQ ditempatkan)
	_run()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func check_eq(name: String, expected, actual) -> void:
	check(name, expected == actual, "expected=%s actual=%s" % [expected, actual])


func _run() -> void:
	var fs: FleetSystem = SystemRefs.fleet_system()
	var wd: WaveDirector = SystemRefs.wave_director()
	check("asset.systems_present", fs != null and wd != null)
	if fs == null or wd == null:
		_finish()
		return

	# 1. data: model_path terisi untuk SHP-001
	var def := GameData.get_ship_def(&"shp_001_interceptor")
	check("asset.def_present", def != null)
	if def == null:
		_finish()
		return
	check("asset.model_path_set", def.model_path != "", def.model_path)

	# 2. spawn 6 interceptor — model GLB harus ter-load semua + collision hull ada
	for i in 6:
		fs.spawn_ship(&"shp_001_interceptor")
	await get_tree().process_frame
	check_eq("asset.fleet_size", 6, fs.alive_count())
	var with_model := 0
	var with_collision := 0
	for s in fs.ships.values():
		if s.model_root != null:
			with_model += 1
			if s.model_root.find_child("HullCollision", true, false) != null:
				with_collision += 1
	check_eq("asset.models_loaded", 6, with_model)
	check_eq("asset.hull_collision_present", 6, with_collision)

	# 3. orientasi + skala dari instance nyata (kontrak ASSET_PIPELINE.md §2)
	var s0: Ship = fs.ships.values()[0]
	var aabb := MeshUtil.model_aabb(s0.model_root)
	check("asset.scale_contract_2_6m", aabb.size.z >= 2.0 and aabb.size.z <= 6.0,
		"panjang_z=%.2f m" % aabb.size.z)
	var wpn := s0.model_root.find_child("SHP001_Weapon_T", true, false) as MeshInstance3D
	var eng := s0.model_root.find_child("SHP001_Engine_L", true, false) as MeshInstance3D
	check("asset.markers_present", wpn != null and eng != null)
	if wpn != null and eng != null:
		var z_wpn := MeshUtil.aabb_in_root(wpn, s0.model_root).get_center().z
		var z_eng := MeshUtil.aabb_in_root(eng, s0.model_root).get_center().z
		check("asset.orientation_nose_minus_z", z_wpn < z_eng,
			"weapon_z=%.2f engine_z=%.2f" % [z_wpn, z_eng])
	QaMarkers.marker("ASSET", "FLEET", {"models": with_model, "panjang_m": roundf(aabb.size.z * 100.0) / 100.0})

	# 3b. pilot ALN-001 (sisi alien): model_path terisi + spawn via Ship
	var adef := GameData.get_ship_def(&"aln_001_scout")
	check("asset.aln_def_present", adef != null)
	if adef != null:
		check("asset.aln_model_path_set", adef.model_path != "", adef.model_path)
		var sa := Ship.new()
		sa.setup(adef, "asset_aln_1")
		add_child(sa)
		await get_tree().process_frame
		check("asset.aln_model_loaded", sa.model_root != null)
		if sa.model_root != null:
			var abody := sa.model_root.find_child("ALN001_Body", true, false) as MeshInstance3D
			var acore := sa.model_root.find_child("ALN001_Core", true, false) as MeshInstance3D
			check("asset.aln_markers_present", abody != null and acore != null)
			var aaabb := MeshUtil.model_aabb(sa.model_root)
			check("asset.aln_scale_contract_2_6m", aaabb.size.z >= 2.0 and aaabb.size.z <= 6.0,
				"panjang_z=%.2f m" % aaabb.size.z)
			sa.queue_free()

	# 4. wave 1 — CombatVisualizer menampilkan model defender + attacker (ALN-001)
	wd.schedule_wave(&"wave_1")
	TimeSystem.advance_ticks(200)
	check("asset.wave_ran", wd.last_result != null)
	TimeSystem.pause()
	await EventBus.combat_visual_done
	TimeSystem.resume()
	var cv: CombatVisualizer = get_tree().get_first_node_in_group("system_combat_visualizer")
	var battle_models := 0
	if cv != null:
		for c in cv.get_children():
			if c is Node3D and (c as Node3D).find_child("SHP001_Body", true, false) != null:
				battle_models += 1
	check("asset.battle_view_has_models", battle_models > 0, "battle_models=%d" % battle_models)
	var battle_alien := 0
	if cv != null:
		for c in cv.get_children():
			if c is Node3D and (c as Node3D).find_child("ALN001_Body", true, false) != null:
				battle_alien += 1
	check("asset.battle_view_has_alien_models", battle_alien > 0,
		"battle_alien_models=%d" % battle_alien)
	QaMarkers.marker("ASSET", "BATTLE", {
		"winner": wd.last_result.winner if wd.last_result != null else "none",
		"battle_models": battle_models,
		"battle_alien_models": battle_alien,
	})
	_finish()


func _finish() -> void:
	print("TESTS:DONE passed=%d failed=%d skipped=0" % [passed, failed])
	QaMarkers.marker("ASSET", "READY", {"passed": passed, "failed": failed})
