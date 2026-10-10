extends RefCounted
## TestDataValidation — validasi DATA NYATA (bukan asumsi): load res://data/*.tres
## asli, cek id unik, referensi resolve, nilai valid, kelengkapan
## (DATA_CONTRACTS.md §3, QA_PLAN.md §2).


func run(t) -> void:
	t.check("data.economy_config_loaded", GameData.economy_config != null)
	t.check("data.progression_config_loaded", GameData.progression_config != null)
	t.check("data.no_load_errors", GameData.load_errors.is_empty(), str(GameData.load_errors))
	t.check("data.buildings_present", GameData.buildings.size() >= 6, "count=%d" % GameData.buildings.size())
	t.check("data.ships_present", GameData.ships.size() >= 3, "count=%d" % GameData.ships.size())
	t.check("data.weapons_present", GameData.weapons.size() >= 2, "count=%d" % GameData.weapons.size())
	t.check("data.waves_present", GameData.waves.size() >= 2, "count=%d" % GameData.waves.size())
	t.check("data.sectors_present", GameData.sectors.size() >= 2, "count=%d" % GameData.sectors.size())

	# Referensi resolve
	for id in GameData.ships.keys():
		var s: ShipDef = GameData.ships[id]
		t.check("data.ship_weapon_resolves.%s" % id, GameData.weapons.has(s.weapon_id), "weapon=%s" % s.weapon_id)
		t.check("data.ship_hp_positive.%s" % id, s.max_hp > 0)
		t.check("data.ship_cost_nonneg.%s" % id, _dict_nonneg(s.cost))
	for id in GameData.waves.keys():
		var w: WaveDef = GameData.waves[id]
		var total := 0
		for ship_id in w.composition.keys():
			t.check("data.wave_ship_resolves.%s.%s" % [id, ship_id], GameData.ships.has(ship_id))
			total += int(w.composition[ship_id])
		t.check("data.wave_nonempty.%s" % id, total > 0, "units=%d" % total)
		t.check("data.wave_telegraph_positive.%s" % id, w.telegraph_ticks > 0)
	for id in GameData.sectors.keys():
		var s: SectorDef = GameData.sectors[id]
		for w in s.waves:
			t.check("data.sector_wave_resolves.%s.%s" % [id, w], GameData.waves.has(w))
		for res_id in s.rewards.keys():
			t.check("data.sector_reward_resource.%s.%s" % [id, res_id], GameData.economy_config.storage_caps.has(res_id))

	# Nilai bangunan valid
	for id in GameData.buildings.keys():
		var b: BuildingDef = GameData.buildings[id]
		t.check("data.building_cost_nonneg.%s" % id, _dict_nonneg(b.base_cost))
		t.check("data.building_hp_positive.%s" % id, b.max_hp > 0)
		t.check("data.building_time_nonneg.%s" % id, b.build_time_ticks >= 0)
		t.check("data.building_max_level.%s" % id, b.max_level >= 1)
		if b.category == "defense" and b.weapon_id != &"":
			t.check("data.defense_weapon_resolves.%s" % id, GameData.weapons.has(b.weapon_id), "weapon=%s" % b.weapon_id)
		if b.produces != &"":
			t.check("data.producer_rate_positive.%s" % id, b.production_per_minute > 0)
			t.check("data.producer_resource_known.%s" % id, GameData.economy_config.storage_caps.has(str(b.produces)))

	# Ekonomi awal: fasilitas ekonomi pertama harus terjangkau (loop bisa dimulai)
	var cfg := GameData.economy_config
	var start_e := int(cfg.starting_resources.get("energy", 0))
	var start_m := int(cfg.starting_resources.get("minerals", 0))
	var affordable := false
	for id in GameData.buildings.keys():
		var b: BuildingDef = GameData.buildings[id]
		if b.category == "economy":
			if int(b.base_cost.get("energy", 0)) <= start_e and int(b.base_cost.get("minerals", 0)) <= start_m:
				affordable = true
	t.check("data.first_economy_building_affordable", affordable)

	# Progresi awal: semua starting_unlocks adalah bangunan/kapal yang ada
	if GameData.progression_config != null:
		for id in GameData.progression_config.starting_unlocks:
			t.check("data.starting_unlock_resolves.%s" % id, GameData.buildings.has(id) or GameData.ships.has(id))
		for id in GameData.progression_config.starting_territories:
			t.check("data.starting_territory_resolves.%s" % id, GameData.sectors.has(id))


func _dict_nonneg(d: Dictionary) -> bool:
	for k in d.keys():
		if int(d[k]) < 0:
			return false
	return true
