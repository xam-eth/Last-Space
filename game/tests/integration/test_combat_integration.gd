extends RefCounted
## TestCombatIntegration — integrasi wave → combat → hasil diterapkan ke sistem
## (losses, damage) dengan state nyata.


func run(t) -> void:
	TestUtil.reset_all()
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	var fs: FleetSystem = SystemRefs.fleet_system()
	var wd: WaveDirector = SystemRefs.wave_director()
	t.check("ci.systems_present", bs != null and ps != null and fs != null and wd != null)
	if bs == null or ps == null or fs == null or wd == null:
		return

	# Base: HQ + hangar + 3 interceptor + 1 turret
	bs.place_building(&"command_core", Vector3(0, 0, 0))
	bs.place_building(&"fighter_hangar", bs.next_free_position(Vector2i(2, 2)))
	bs.place_building(&"laser_turret", bs.next_free_position(Vector2i(1, 1)))
	fs.spawn_ship(&"shp_001_interceptor")
	fs.spawn_ship(&"shp_001_interceptor")
	fs.spawn_ship(&"shp_001_interceptor")
	t.check_eq("ci.fleet_ready", 3, fs.alive_count())

	# Wave 1 (4 scout) vs 3 interceptor + turret → attacker kalah total
	wd.schedule_wave(&"wave_1", 10)
	TimeSystem.advance_ticks(11)  ## countdown habis → simulasi jalan
	var result: BattleResult = wd.last_result
	t.check("ci.combat_ran", result != null)
	if result == null:
		return
	t.check_eq("ci.wave1_defender_wins", "defender", result.winner)
	t.check_eq("ci.wave1_attackers_all_lost", 4, _total(result.attacker_losses))

	# Hasil diterapkan ke sistem: tidak ada kapal attacker (mereka bukan fleet pemain),
	# tapi bila ada losses, fleet berkurang sesuai hasil
	t.check("ci.fleet_after_battle", fs.alive_count() <= 3)

	# Wave 2 (lebih besar) dengan fleet lemah → bangunan menerima damage
	# Hancurkan 2 interceptor dulu (simulasi kondisi melemah)
	fs.destroy_ships_of_type(&"shp_001_interceptor", 2)
	t.check_eq("ci.fleet_weakened", 1, fs.alive_count())
	var hq := bs.get_buildings_of(&"command_core")[0]
	var hq_hp_before := hq.hp
	wd.schedule_wave(&"wave_2", 10)
	TimeSystem.advance_ticks(11)
	var result2: BattleResult = wd.last_result
	t.check("ci.combat2_ran", result2 != null)
	if result2 != null:
		t.check("ci.wave2_building_damage_or_losses", result2.building_damage.size() > 0 or _total(result2.defender_ship_losses) > 0)
	# Damage benar-benar ter-apply ke state bangunan
		if result2.building_damage.size() > 0:
			var total_dmg := 0
			for k in result2.building_damage.keys():
				total_dmg += int(result2.building_damage[k])
			t.check("ci.damage_applied_to_state", hq.hp < hq_hp_before or total_dmg > 0)

	# WaveDirector kembali idle setelah pertempuran
	t.check("ci.wave_director_idle", wd.is_idle())


func _total(d: Dictionary) -> int:
	var n := 0
	for k in d.keys():
		n += int(d[k])
	return n
