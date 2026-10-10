extends RefCounted
## TestSaveLoad — round-trip save/load: state setelah load harus sama persis
## (AI_GOVERNANCE.md §16, QA_PLAN.md phase 5).


func run(t) -> void:
	TestUtil.reset_all()
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	var fs: FleetSystem = SystemRefs.fleet_system()
	var pr: ProgressionSystem = SystemRefs.progression_system()
	var wd: WaveDirector = SystemRefs.wave_director()
	t.check("sl.systems_present", bs != null and ps != null and fs != null and pr != null and wd != null)
	if bs == null or ps == null or fs == null or pr == null or wd == null:
		return

	# Bangun state yang non-trivial
	bs.place_building(&"command_core", Vector3(0, 0, 0))
	bs.place_building(&"energy_reactor", Vector3(4, 0, 0))
	fs.spawn_ship(&"shp_001_interceptor")
	fs.spawn_ship(&"shp_001_interceptor")
	fs.destroy_ships_of_type(&"shp_001_interceptor", 1)
	pr.grant_reward({"energy": 100}, "save_test_source")
	TimeSystem.advance_ticks(120)
	Economy.spend({"energy": 30})

	# Snapshot sebelum save
	var eco_before := Economy.get_state()
	var buildings_before := bs.get_state()
	var fleet_before := fs.get_state()
	var prog_before := pr.get_state()
	var ticks_before := TimeSystem.tick_count

	t.check("sl.save_ok", SaveSystem.save_game("test_slot"))
	t.check("sl.save_file_exists", SaveSystem.has_save("test_slot"))

	# Reset total (simulasi game baru), lalu load kembali
	TestUtil.reset_all()
	t.check("sl.state_reset", bs.get_all_buildings().size() == 0 and fs.total_count() == 0)

	t.check("sl.load_ok", SaveSystem.load_game("test_slot"))
	t.check_eq("sl.economy_restored", JSON.stringify(eco_before), JSON.stringify(Economy.get_state()))
	t.check_eq("sl.buildings_restored", JSON.stringify(buildings_before), JSON.stringify(bs.get_state()))
	t.check_eq("sl.fleet_restored", JSON.stringify(fleet_before), JSON.stringify(fs.get_state()))
	t.check_eq("sl.progression_restored", JSON.stringify(prog_before), JSON.stringify(pr.get_state()))
	t.check_eq("sl.ticks_restored", ticks_before, TimeSystem.tick_count)

	# Reward tidak ganda setelah load ulang
	var e_after := Economy.get_amount(&"energy")
	SaveSystem.load_game("test_slot")
	t.check_eq("sl.no_duplicate_reward_after_reload", e_after, Economy.get_amount(&"energy"))

	# Load slot yang tidak ada → gagal dengan jelas
	t.check("sl.missing_slot_fails", not SaveSystem.load_game("slot_tidak_ada"))

	# Save data valid JSON dengan schema_version + semua section
	var f := FileAccess.open("user://test_slot.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	t.check_eq("sl.schema_version", 1, int(data.get("schema_version", 0)))
	t.check("sl.save_has_all_sections", data.has("economy") and data.has("buildings") and data.has("fleet") and data.has("progression") and data.has("wave_director"))
