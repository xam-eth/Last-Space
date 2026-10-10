class_name TestUtil
## TestUtil — helper isolasi test: reset semua sistem ke state awal (fresh)
## agar test tidak saling mengganggu (shared autoload/systems).


static func reset_all() -> void:
	GameManager.start_new_game(1)  ## Economy.reset + phase COMMAND
	var bs := SystemRefs.building_system()
	var ps := SystemRefs.production_system()
	var fs := SystemRefs.fleet_system()
	var pr := SystemRefs.progression_system()
	var wd := SystemRefs.wave_director()
	if bs != null:
		bs.set_state({})
	if ps != null:
		ps.set_state({})
	if fs != null:
		fs.set_state({})
	if pr != null:
		var cfg := GameData.progression_config
		var fresh_unlocks: Array[StringName] = []
		var fresh_territories: Array[StringName] = []
		if cfg != null:
			for v in cfg.starting_unlocks:
				fresh_unlocks.append(StringName(v))
			for v in cfg.starting_territories:
				fresh_territories.append(StringName(v))
		pr.set_state({
			"unlocked": fresh_unlocks,
			"territories": fresh_territories,
			"granted_rewards": [],
			"defense_wins": 0,
		})
	if wd != null:
		wd.set_state({})
	TimeSystem.tick_count = 0
