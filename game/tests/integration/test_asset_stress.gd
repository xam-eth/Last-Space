extends RefCounted
## TestAssetStress — performa pilot asset SHP-001 (ASSET_ACCEPTANCE_CRITERIA.md
## §4 butir 5): N instance model GLB diukur waktu nyata + total tri.

func run(t) -> void:
	var fs: FleetSystem = SystemRefs.fleet_system()
	t.check("stress.fleet_present", fs != null)
	if fs == null:
		return
	# bersihkan armada lebih dulu (test lain bisa meninggalkan kapal — data nyata)
	for id in fs.ships.keys():
		fs.remove_ship(id)
	var n := 100
	var t0 := Time.get_ticks_msec()
	for i in n:
		fs.spawn_ship(&"shp_001_interceptor")
	var t1 := Time.get_ticks_msec()
	var ok := 0
	var tris := 0
	for s in fs.ships.values():
		if s.model_root != null and not s.is_destroyed():
			ok += 1
			for mi in s.model_root.find_children("*", "MeshInstance3D", true, false):
				tris += MeshUtil.tri_count((mi as MeshInstance3D).mesh)
	t.check_eq("stress.models_loaded", n, ok)
	t.check("stress.spawn_time_budget", (t1 - t0) < 5000,
		"%d ship (model GLB) spawn dalam %d ms (%.1f ms/ship)" % [n, t1 - t0, float(t1 - t0) / n])
	t.check("stress.tri_count_reported", tris > 0,
		"total_tris=%d (%.0f tris/ship)" % [tris, float(tris) / n])
	for id in fs.ships.keys():
		fs.remove_ship(id)
	t.check_eq("stress.cleaned_up", 0, fs.total_count())
